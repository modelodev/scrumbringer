//// Task workflow actor for business logic orchestration.
////
//// ## Mission
////
//// Centralizes task-related business logic including validation, authorization,
//// state transitions, and coordination of database operations. Separates business
//// concerns from HTTP handling and pure CRUD.
////
//// ## Responsibilities
////
//// - Input validation (title, priority, type_id)
//// - Authorization checks (project membership, claim ownership)
//// - State transition rules (claim, release, complete)
//// - Coordination of DB calls
//// - Domain error mapping
////
//// ## Non-responsibilities
////
//// - HTTP request parsing (see `http/tasks.gleam`)
//// - JSON serialization (see `http/tasks/presenters.gleam`)
//// - Pure SQL queries (see `services/tasks_db.gleam`)

import gleam/option.{type Option, None, Some}
import gleam/string
import pog
import scrumbringer_server/domain/task_status.{Available, Claimed, Completed}
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/task_types_db
import scrumbringer_server/services/tasks_db
import scrumbringer_server/sql

// =============================================================================
// Message Types
// =============================================================================

/// Task workflow messages for business logic operations.
pub type Message {
  /// List task types for a project.
  ListTaskTypes(project_id: Int, user_id: Int)

  /// Create a new task type in a project.
  CreateTaskType(
    project_id: Int,
    user_id: Int,
    org_id: Int,
    name: String,
    icon: String,
    capability_id: Option(Int),
  )

  /// List tasks with filters.
  ListTasks(project_id: Int, user_id: Int, filters: TaskFilters)

  /// Create a new task.
  CreateTask(
    project_id: Int,
    user_id: Int,
    org_id: Int,
    title: String,
    description: String,
    priority: Int,
    type_id: Int,
  )

  /// Get a single task.
  GetTask(task_id: Int, user_id: Int)

  /// Update a task (owner only).
  UpdateTask(task_id: Int, user_id: Int, version: Int, updates: TaskUpdates)

  /// Claim an available task.
  ClaimTask(task_id: Int, user_id: Int, org_id: Int, version: Int)

  /// Release a claimed task (owner only).
  ReleaseTask(task_id: Int, user_id: Int, org_id: Int, version: Int)

  /// Complete a claimed task (owner only).
  CompleteTask(task_id: Int, user_id: Int, org_id: Int, version: Int)
}

/// Task list filters.
pub type TaskFilters {
  TaskFilters(status: String, type_id: Int, capability_id: Int, q: String)
}

/// Task update fields (sentinel values indicate no change).
pub type TaskUpdates {
  TaskUpdates(title: String, description: String, priority: Int, type_id: Int)
}

// =============================================================================
// Response Types
// =============================================================================

/// Successful response variants.
pub type Response {
  TaskTypesList(List(task_types_db.TaskType))
  TaskTypeCreated(task_types_db.TaskType)
  TasksList(List(tasks_db.Task))
  TaskResult(tasks_db.Task)
}

// =============================================================================
// Error Types
// =============================================================================

/// Domain errors for task operations.
pub type Error {
  /// User is not authorized (not a project member/admin).
  NotAuthorized

  /// Resource not found.
  NotFound

  /// Validation error with message.
  ValidationError(String)

  /// Task type name already exists.
  TaskTypeAlreadyExists

  /// Task is already claimed by someone else.
  AlreadyClaimed

  /// Invalid state transition (e.g., release unclaimed task).
  InvalidTransition

  /// Version conflict (optimistic locking).
  VersionConflict

  /// Claim ownership conflict (task claimed by another user).
  ClaimOwnershipConflict(current_claimed_by: Option(Int))

  /// Database error.
  DbError(pog.QueryError)
}

// =============================================================================
// Constants
// =============================================================================

/// Maximum allowed characters for task title.
const max_task_title_chars = 56

/// Sentinel value indicating an optional string field was not provided.
pub const unset_string = "__unset__"

// =============================================================================
// Handler
// =============================================================================

/// Handle a task workflow message and return a domain result.
pub fn handle(db: pog.Connection, message: Message) -> Result(Response, Error) {
  case message {
    ListTaskTypes(project_id, user_id) ->
      handle_list_task_types(db, project_id, user_id)

    CreateTaskType(project_id, user_id, org_id, name, icon, capability_id) ->
      handle_create_task_type(
        db,
        project_id,
        user_id,
        org_id,
        name,
        icon,
        capability_id,
      )

    ListTasks(project_id, user_id, filters) ->
      handle_list_tasks(db, project_id, user_id, filters)

    CreateTask(
      project_id,
      user_id,
      org_id,
      title,
      description,
      priority,
      type_id,
    ) ->
      handle_create_task(
        db,
        project_id,
        user_id,
        org_id,
        title,
        description,
        priority,
        type_id,
      )

    GetTask(task_id, user_id) -> handle_get_task(db, task_id, user_id)

    UpdateTask(task_id, user_id, version, updates) ->
      handle_update_task(db, task_id, user_id, version, updates)

    ClaimTask(task_id, user_id, org_id, version) ->
      handle_claim_task(db, task_id, user_id, org_id, version)

    ReleaseTask(task_id, user_id, org_id, version) ->
      handle_release_task(db, task_id, user_id, org_id, version)

    CompleteTask(task_id, user_id, org_id, version) ->
      handle_complete_task(db, task_id, user_id, org_id, version)
  }
}

// =============================================================================
// Message Handlers
// =============================================================================

fn handle_list_task_types(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Response, Error) {
  use _ <- require_project_member(db, project_id, user_id)

  case task_types_db.list_task_types_for_project(db, project_id) {
    Ok(task_types) -> Ok(TaskTypesList(task_types))
    Error(e) -> Error(DbError(e))
  }
}

fn handle_create_task_type(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  org_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> Result(Response, Error) {
  use _ <- require_project_admin(db, project_id, user_id)
  use _ <- validate_capability_in_org(db, capability_id, org_id)

  case
    task_types_db.create_task_type(db, project_id, name, icon, capability_id)
  {
    Ok(task_type) -> Ok(TaskTypeCreated(task_type))
    Error(task_types_db.AlreadyExists) -> Error(TaskTypeAlreadyExists)
    Error(task_types_db.InvalidCapabilityId) ->
      Error(ValidationError("Invalid capability_id"))
    Error(task_types_db.DbError(e)) -> Error(DbError(e))
    Error(task_types_db.NoRowReturned) ->
      Error(ValidationError("Failed to create task type"))
  }
}

fn handle_list_tasks(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  filters: TaskFilters,
) -> Result(Response, Error) {
  use _ <- require_project_member(db, project_id, user_id)

  case
    tasks_db.list_tasks_for_project(
      db,
      project_id,
      user_id,
      filters.status,
      filters.type_id,
      filters.capability_id,
      filters.q,
    )
  {
    Ok(tasks) -> Ok(TasksList(tasks))
    Error(e) -> Error(DbError(e))
  }
}

fn handle_create_task(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  org_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
) -> Result(Response, Error) {
  use _ <- require_project_member(db, project_id, user_id)
  use validated_title <- validate_task_title(title)
  use _ <- validate_priority(priority)
  use _ <- validate_task_type_in_project(db, type_id, project_id)

  case
    tasks_db.create_task(
      db,
      org_id,
      type_id,
      project_id,
      validated_title,
      description,
      priority,
      user_id,
    )
  {
    Ok(task) -> Ok(TaskResult(task))
    Error(tasks_db.InvalidTypeId) -> Error(ValidationError("Invalid type_id"))
    Error(tasks_db.CreateDbError(e)) -> Error(DbError(e))
  }
}

fn handle_get_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Response, Error) {
  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(TaskResult(task))
    Error(tasks_db.NotFound) -> Error(NotFound)
    Error(tasks_db.DbError(e)) -> Error(DbError(e))
  }
}

fn handle_update_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
  updates: TaskUpdates,
) -> Result(Response, Error) {
  use _ <- validate_optional_priority(updates.priority)

  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Error(tasks_db.NotFound) -> Error(NotFound)
    Error(tasks_db.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Available | Completed -> Error(NotAuthorized)

        Claimed(_) ->
          case current.claimed_by {
            Some(id) if id == user_id -> {
              use _ <- validate_type_update(
                db,
                updates.type_id,
                current.project_id,
              )

              case
                tasks_db.update_task_claimed_by_user(
                  db,
                  task_id,
                  user_id,
                  updates.title,
                  updates.description,
                  updates.priority,
                  updates.type_id,
                  version,
                )
              {
                Ok(task) -> Ok(TaskResult(task))
                Error(tasks_db.NotFound) -> Error(VersionConflict)
                Error(tasks_db.DbError(e)) -> Error(DbError(e))
              }
            }

            _ -> Error(NotAuthorized)
          }
      }
  }
}

fn handle_claim_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
) -> Result(Response, Error) {
  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Error(tasks_db.NotFound) -> Error(NotFound)
    Error(tasks_db.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Claimed(_) -> Error(AlreadyClaimed)
        Completed -> Error(InvalidTransition)

        Available ->
          case tasks_db.claim_task(db, org_id, task_id, user_id, version) {
            Ok(task) -> Ok(TaskResult(task))
            Error(tasks_db.NotFound) -> detect_conflict(db, task_id, user_id)
            Error(tasks_db.DbError(e)) -> Error(DbError(e))
          }
      }
  }
}

fn handle_release_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
) -> Result(Response, Error) {
  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Error(tasks_db.NotFound) -> Error(NotFound)
    Error(tasks_db.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Available | Completed -> Error(InvalidTransition)

        Claimed(_) ->
          case current.claimed_by {
            Some(id) if id == user_id ->
              case
                tasks_db.release_task(db, org_id, task_id, user_id, version)
              {
                Ok(task) -> Ok(TaskResult(task))
                Error(tasks_db.NotFound) -> Error(VersionConflict)
                Error(tasks_db.DbError(e)) -> Error(DbError(e))
              }

            _ -> Error(NotAuthorized)
          }
      }
  }
}

fn handle_complete_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
) -> Result(Response, Error) {
  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Error(tasks_db.NotFound) -> Error(NotFound)
    Error(tasks_db.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Available | Completed -> Error(InvalidTransition)

        Claimed(_) ->
          case current.claimed_by {
            Some(id) if id == user_id ->
              case
                tasks_db.complete_task(db, org_id, task_id, user_id, version)
              {
                Ok(task) -> Ok(TaskResult(task))
                Error(tasks_db.NotFound) -> Error(VersionConflict)
                Error(tasks_db.DbError(e)) -> Error(DbError(e))
              }

            _ -> Error(NotAuthorized)
          }
      }
  }
}

// =============================================================================
// Validation Helpers
// =============================================================================

fn validate_task_title(
  title: String,
  next: fn(String) -> Result(Response, Error),
) -> Result(Response, Error) {
  let title = string.trim(title)

  case title == "" {
    True -> Error(ValidationError("Title is required"))
    False ->
      case string.length(title) <= max_task_title_chars {
        True -> next(title)
        False -> Error(ValidationError("Title too long (max 56 characters)"))
      }
  }
}

fn validate_priority(
  priority: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case priority >= 1 && priority <= 5 {
    True -> next(Nil)
    False -> Error(ValidationError("Invalid priority"))
  }
}

fn validate_optional_priority(
  priority: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case priority {
    -1 -> next(Nil)
    _ -> validate_priority(priority, next)
  }
}

fn validate_task_type_in_project(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case task_types_db.is_task_type_in_project(db, type_id, project_id) {
    Ok(True) -> next(Nil)
    Ok(False) -> Error(ValidationError("Invalid type_id"))
    Error(e) -> Error(DbError(e))
  }
}

fn validate_type_update(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case type_id {
    -1 -> next(Nil)
    id -> validate_task_type_in_project(db, id, project_id, next)
  }
}

fn validate_capability_in_org(
  db: pog.Connection,
  capability_id: Option(Int),
  org_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case capability_id {
    None -> next(Nil)

    Some(id) ->
      case sql.capabilities_is_in_org(db, id, org_id) {
        Ok(pog.Returned(rows: [row, ..], ..)) ->
          case row.ok {
            True -> next(Nil)
            False -> Error(ValidationError("Invalid capability_id"))
          }

        Ok(pog.Returned(rows: [], ..)) ->
          Error(ValidationError("Invalid capability_id"))

        Error(e) -> Error(DbError(e))
      }
  }
}

// =============================================================================
// Authorization Helpers
// =============================================================================

fn require_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case projects_db.is_project_member(db, project_id, user_id) {
    Ok(True) -> next(Nil)
    Ok(False) -> Error(NotAuthorized)
    Error(e) -> Error(DbError(e))
  }
}

fn require_project_admin(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case projects_db.is_project_admin(db, project_id, user_id) {
    Ok(True) -> next(Nil)
    Ok(False) -> Error(NotAuthorized)
    Error(e) -> Error(DbError(e))
  }
}

// =============================================================================
// Conflict Detection
// =============================================================================

fn detect_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Response, Error) {
  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Error(tasks_db.NotFound) -> Error(NotFound)
    Error(tasks_db.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Claimed(_) -> Error(ClaimOwnershipConflict(current.claimed_by))
        _ -> Error(VersionConflict)
      }
  }
}
