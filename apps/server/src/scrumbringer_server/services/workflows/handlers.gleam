//// Task workflow message handlers.
////
//// ## Mission
////
//// Handles task workflow messages by coordinating validation, authorization,
//// and database operations. This is the main entry point for task business logic.
////
//// ## Responsibilities
////
//// - Route messages to appropriate handlers
//// - Coordinate validation and authorization
//// - Execute database operations
//// - Map database errors to domain errors
////
//// ## Non-responsibilities
////
//// - HTTP request parsing (see `http/tasks.gleam`)
//// - JSON serialization (see `http/tasks/presenters.gleam`)
//// - Pure SQL queries (see `persistence/tasks/queries.gleam`)
////
//// ## Relations
////
//// - **types.gleam**: Message, Response, Error types
//// - **validation.gleam**: Input validation helpers
//// - **authorization.gleam**: Authorization checks

import domain/field_update
import domain/milestone
import domain/task_state
import domain/task_status.{Available, Claimed, Completed, task_status_to_string}
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/persistence/tasks/mappers as task_mappers
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/cards_db
import scrumbringer_server/services/milestones_db
import scrumbringer_server/services/rules_engine
import scrumbringer_server/services/service_error
import scrumbringer_server/services/task_types_db
import scrumbringer_server/services/work_sessions_db
import scrumbringer_server/services/workflows/authorization
import scrumbringer_server/services/workflows/types.{
  type Error, type Message, type Response, type TaskFilters, type TaskUpdates,
  AlreadyClaimed, ClaimOwnershipConflict, ClaimTask, CompleteTask, CreateTask,
  CreateTaskType, DbError, DeleteTaskType, GetTask, InvalidMovePoolToMilestone,
  InvalidTransition, ListTaskTypes, ListTasks, NotAuthorized, NotFound,
  ReleaseTask, TaskMilestoneInheritedFromCard, TaskResult, TaskTypeAlreadyExists,
  TaskTypeCreated, TaskTypeDeleted, TaskTypeInUse, TaskTypeUpdated,
  TaskTypesList, TasksList, UpdateTask, UpdateTaskType, ValidationError,
  VersionConflict,
}
import scrumbringer_server/services/workflows/validation

// =============================================================================
// Main Handler
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

    UpdateTaskType(type_id, user_id, name, icon, capability_id) ->
      handle_update_task_type(db, type_id, user_id, name, icon, capability_id)

    DeleteTaskType(type_id, user_id) ->
      handle_delete_task_type(db, type_id, user_id)

    ListTasks(project_id, user_id, filters) ->
      handle_list_tasks(db, project_id, user_id, filters)

    CreateTask(
      project_id: project_id,
      user_id: user_id,
      org_id: org_id,
      title: title,
      description: description,
      priority: priority,
      type_id: type_id,
      card_id: card_id,
      milestone_id: milestone_id,
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
        card_id,
        milestone_id,
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
  use _ <- authorization.require_project_member(db, project_id, user_id)

  case task_types_db.list_task_types_for_project(db, project_id) {
    Ok(task_types) -> Ok(TaskTypesList(task_types))
    Error(e) -> Error(DbError(e))
  }
}

fn handle_create_task_type(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  _org_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> Result(Response, Error) {
  use _ <- authorization.require_project_admin(db, project_id, user_id)
  use _ <- validation.validate_capability_in_project(
    db,
    capability_id,
    project_id,
  )

  case
    task_types_db.create_task_type(db, project_id, name, icon, capability_id)
  {
    Ok(task_type) -> Ok(TaskTypeCreated(task_type))
    Error(service_error.AlreadyExists) -> Error(TaskTypeAlreadyExists)
    Error(service_error.InvalidReference("capability_id")) ->
      Error(ValidationError("Invalid capability_id"))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid capability_id"))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Failed to create task type"))
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.Conflict(_)) ->
      Error(ValidationError("Failed to create task type"))
    Error(service_error.NotFound) ->
      Error(ValidationError("Failed to create task type"))
  }
}

// Justification: nested case improves clarity for branching logic.
/// Story 4.9 AC13: Update task type name, icon, or capability.
fn handle_update_task_type(
  db: pog.Connection,
  type_id: Int,
  user_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> Result(Response, Error) {
  case task_types_db.get_task_type_project_id(db, type_id) {
    Ok(Some(project_id)) -> {
      use _ <- authorization.require_project_admin(db, project_id, user_id)
      use _ <- validation.validate_capability_in_project(
        db,
        capability_id,
        project_id,
      )

      case
        task_types_db.update_task_type(db, type_id, name, icon, capability_id)
      {
        Ok(task_type) -> Ok(TaskTypeUpdated(task_type))
        Error(service_error.NotFound) -> Error(NotFound)
        Error(service_error.DbError(e)) -> Error(DbError(e))
        Error(service_error.Conflict(_)) ->
          Error(ValidationError("Failed to update task type"))
        Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
        Error(service_error.InvalidReference(_)) ->
          Error(ValidationError("Invalid capability_id"))
        Error(service_error.Unexpected(_)) ->
          Error(ValidationError("Failed to update task type"))
        Error(service_error.AlreadyExists) ->
          Error(ValidationError("Task type already exists"))
      }
    }

    Ok(None) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Story 4.9 AC14: Delete task type (only if no tasks use it).
fn handle_delete_task_type(
  db: pog.Connection,
  type_id: Int,
  _user_id: Int,
) -> Result(Response, Error) {
  case task_types_db.delete_task_type(db, type_id) {
    Ok(deleted_id) -> Ok(TaskTypeDeleted(deleted_id))
    Error(service_error.Conflict("task_type_in_use")) -> Error(TaskTypeInUse)
    Error(service_error.Conflict(_)) ->
      Error(ValidationError("Failed to delete task type"))
    Error(service_error.NotFound) -> Error(NotFound)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Failed to delete task type"))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Failed to delete task type"))
    Error(service_error.AlreadyExists) ->
      Error(ValidationError("Failed to delete task type"))
  }
}

fn handle_list_tasks(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  filters: TaskFilters,
) -> Result(Response, Error) {
  use _ <- authorization.require_project_member(db, project_id, user_id)

  case
    tasks_queries.list_tasks_for_project(
      db,
      project_id,
      user_id,
      filters.status,
      filters.type_id,
      filters.capability_id,
      filters.q,
      filters.blocked,
    )
  {
    Ok(tasks) -> Ok(TasksList(tasks))
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.Unexpected(_)) ->
      Error(DbError(pog.UnexpectedArgumentCount(1, 0)))
    Error(_) -> Error(DbError(pog.UnexpectedArgumentCount(1, 0)))
  }
}

// Justification: nested case improves clarity for branching logic.
fn handle_create_task(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  org_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
  card_id: Option(Int),
  milestone_id: Option(Int),
) -> Result(Response, Error) {
  use _ <- authorization.require_project_member(db, project_id, user_id)
  use validated_title <- validation.validate_task_title(title)
  use _ <- validation.validate_priority(priority)
  use _ <- validation.validate_task_type_in_project(db, type_id, project_id)

  let normalized_card_id = case card_id {
    None -> Ok(None)
    Some(0) -> Ok(None)
    Some(id) if id > 0 -> Ok(Some(id))
    Some(_) -> Error(ValidationError("Invalid card_id"))
  }

  case normalized_card_id {
    Error(err) -> Error(err)
    Ok(card_id) ->
      case
        tasks_queries.create_task(
          db,
          org_id,
          type_id,
          project_id,
          validated_title,
          description,
          priority,
          user_id,
          card_id,
          milestone_id,
          None,
        )
      {
        Ok(task) -> {
          // Trigger rules engine for task creation (null → available)
          let ctx =
            rules_engine.TaskContext(
              task.id,
              project_id,
              org_id,
              type_id,
              card_id,
            )
          let _ = evaluate_task_rules_created(db, ctx, user_id)
          Ok(TaskResult(task))
        }
        Error(service_error.InvalidReference("type_id")) ->
          Error(ValidationError("Invalid type_id"))
        Error(service_error.InvalidReference("card_id")) ->
          Error(ValidationError("Invalid card_id"))
        Error(service_error.InvalidReference(_)) ->
          Error(ValidationError("Invalid reference"))
        Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
        Error(service_error.DbError(e)) -> Error(DbError(e))
        Error(service_error.Unexpected(_)) ->
          Error(ValidationError("Unexpected error"))
        Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
        Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))
        Error(service_error.NotFound) -> Error(NotFound)
      }
  }
}

fn handle_get_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Response, Error) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(TaskResult(task))
    Error(service_error.NotFound) -> Error(NotFound)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))
  }
}

fn handle_update_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
  updates: TaskUpdates,
) -> Result(Response, Error) {
  use _ <- validation.validate_optional_priority(updates.priority)

  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(service_error.NotFound) -> Error(NotFound)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))

    Ok(current) ->
      update_task_for_current(db, task_id, user_id, version, updates, current)
  }
}

fn update_task_for_current(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
  updates: TaskUpdates,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case current.status {
    Available | Completed -> Error(NotAuthorized)
    Claimed(_) ->
      update_task_for_claimed(db, task_id, user_id, version, updates, current)
  }
}

fn update_task_for_claimed(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
  updates: TaskUpdates,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case task_state.claimed_by(current.state) {
    Some(id) if id == user_id ->
      update_task_for_owner(db, task_id, user_id, version, updates, current)
    _ -> Error(NotAuthorized)
  }
}

fn update_task_for_owner(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
  updates: TaskUpdates,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  use _ <- validation.validate_type_update(
    db,
    updates.type_id,
    current.project_id,
  )
  use _ <- result.try(validate_milestone_update(
    db,
    current,
    updates.milestone_id,
  ))

  let title_update = field_update.to_option(updates.title)
  let description_update = field_update.to_option(updates.description)
  let priority_update = field_update.to_option(updates.priority)
  let type_id_update = field_update.to_option(updates.type_id)
  let milestone_update = to_milestone_query_value(updates.milestone_id)

  case
    tasks_queries.update_task_claimed_by_user(
      db,
      task_id,
      user_id,
      title_update,
      description_update,
      priority_update,
      type_id_update,
      milestone_update,
      version,
    )
  {
    Ok(task) -> Ok(TaskResult(task))
    Error(service_error.NotFound) -> Error(VersionConflict)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))
  }
}

fn validate_milestone_update(
  db: pog.Connection,
  current: task_mappers.Task,
  milestone_update: field_update.FieldUpdate(Option(Int)),
) -> Result(Response, Error) {
  case milestone_update {
    field_update.Unchanged -> Ok(TaskResult(current))
    field_update.Set(target) ->
      case current.card_id {
        Some(_) -> Error(TaskMilestoneInheritedFromCard)
        None ->
          case
            validate_milestone_move(db, current.project_id, current.id, target)
          {
            Ok(Nil) -> Ok(TaskResult(current))
            Error(e) -> Error(e)
          }
      }
  }
}

fn validate_milestone_move(
  db: pog.Connection,
  project_id: Int,
  task_id: Int,
  target_milestone_id: Option(Int),
) -> Result(Nil, Error) {
  let current_milestone_id = case
    milestones_db.get_effective_milestone_for_task(db, task_id)
  {
    Ok(value) -> Ok(value)
    Error(milestones_db.NotFound) -> Ok(None)
    Error(milestones_db.DeleteNotAllowed) ->
      Error(ValidationError("Invalid milestone_id"))
    Error(milestones_db.DbError(e)) -> Error(DbError(e))
  }

  case current_milestone_id {
    Error(e) -> Error(e)
    Ok(current_id) ->
      case target_milestone_id {
        None ->
          case current_id {
            None -> Ok(Nil)
            Some(id) ->
              case validate_ready_milestone(db, project_id, id) {
                Ok(Nil) -> Ok(Nil)
                Error(ValidationError(_)) -> Error(InvalidMovePoolToMilestone)
                Error(e) -> Error(e)
              }
          }
        Some(target_id) ->
          case current_id {
            None -> Error(InvalidMovePoolToMilestone)
            Some(current_id) ->
              case
                validate_ready_milestone(db, project_id, current_id),
                validate_ready_milestone(db, project_id, target_id)
              {
                Ok(Nil), Ok(Nil) -> Ok(Nil)
                Error(ValidationError(_)), _ ->
                  Error(InvalidMovePoolToMilestone)
                _, Error(ValidationError(_)) ->
                  Error(ValidationError("Invalid milestone_id"))
                Error(e), _ -> Error(e)
                _, Error(e) -> Error(e)
              }
          }
      }
  }
}

fn validate_ready_milestone(
  db: pog.Connection,
  project_id: Int,
  milestone_id: Int,
) -> Result(Nil, Error) {
  case milestones_db.get_milestone(db, milestone_id) {
    Ok(found) -> {
      let milestone.Milestone(project_id: owner_project_id, state: state, ..) =
        found
      case owner_project_id == project_id && state == milestone.Ready {
        True -> Ok(Nil)
        False -> Error(ValidationError("Invalid milestone_id"))
      }
    }
    Error(milestones_db.NotFound) ->
      Error(ValidationError("Invalid milestone_id"))
    Error(milestones_db.DeleteNotAllowed) ->
      Error(ValidationError("Invalid milestone_id"))
    Error(milestones_db.DbError(e)) -> Error(DbError(e))
  }
}

fn to_milestone_query_value(
  update: field_update.FieldUpdate(Option(Int)),
) -> Int {
  case update {
    field_update.Unchanged -> -1
    field_update.Set(None) -> 0
    field_update.Set(Some(id)) -> id
  }
}

fn handle_claim_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
) -> Result(Response, Error) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(service_error.NotFound) -> Error(NotFound)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))

    Ok(current) ->
      claim_task_for_current(db, task_id, user_id, org_id, version, current)
  }
}

fn claim_task_for_current(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case current.status {
    Claimed(_) -> Error(AlreadyClaimed)
    Completed -> Error(InvalidTransition)
    Available ->
      claim_available_task(db, task_id, user_id, org_id, version, current)
  }
}

fn claim_available_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case tasks_queries.claim_task(db, org_id, task_id, user_id, version) {
    Ok(task) -> claim_task_success(db, task_id, user_id, org_id, current, task)
    Error(service_error.NotFound) -> detect_conflict(db, task_id, user_id)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))
  }
}

fn claim_task_success(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  current: task_mappers.Task,
  task: task_mappers.Task,
) -> Result(Response, Error) {
  let ctx =
    rules_engine.TaskContext(
      task_id,
      current.project_id,
      org_id,
      current.type_id,
      current.card_id,
    )
  let from_state = task_status_to_string(current.status)
  let to_state = task_status_to_string(task.status)
  let _ = evaluate_task_rules(db, ctx, user_id, from_state, to_state)

  let _ =
    maybe_evaluate_card_rules(
      db,
      current.card_id,
      current.project_id,
      org_id,
      user_id,
    )
  Ok(TaskResult(task))
}

fn handle_release_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
) -> Result(Response, Error) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(service_error.NotFound) -> Error(NotFound)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))

    Ok(current) ->
      release_task_for_current(db, task_id, user_id, org_id, version, current)
  }
}

fn release_task_for_current(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case current.status {
    Available | Completed -> Error(InvalidTransition)
    Claimed(_) ->
      release_task_for_claimed(db, task_id, user_id, org_id, version, current)
  }
}

fn release_task_for_claimed(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case task_state.claimed_by(current.state) {
    Some(id) if id == user_id ->
      release_task_for_owner(db, task_id, user_id, org_id, version, current)
    _ -> Error(NotAuthorized)
  }
}

fn release_task_for_owner(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  let _ =
    work_sessions_db.close_session_for_task(
      db,
      user_id,
      task_id,
      "task_released",
    )

  case tasks_queries.release_task(db, org_id, task_id, user_id, version) {
    Ok(task) ->
      release_task_success(db, task_id, user_id, org_id, current, task)
    Error(service_error.NotFound) -> Error(VersionConflict)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))
  }
}

fn release_task_success(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  current: task_mappers.Task,
  task: task_mappers.Task,
) -> Result(Response, Error) {
  let ctx =
    rules_engine.TaskContext(
      task_id,
      current.project_id,
      org_id,
      current.type_id,
      current.card_id,
    )
  let from_state = task_status_to_string(current.status)
  let to_state = task_status_to_string(task.status)
  let _ = evaluate_task_rules(db, ctx, user_id, from_state, to_state)

  let _ =
    maybe_evaluate_card_rules(
      db,
      current.card_id,
      current.project_id,
      org_id,
      user_id,
    )
  Ok(TaskResult(task))
}

fn handle_complete_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
) -> Result(Response, Error) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(service_error.NotFound) -> Error(NotFound)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))

    Ok(current) ->
      complete_task_for_current(db, task_id, user_id, org_id, version, current)
  }
}

fn complete_task_for_current(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case current.status {
    Available | Completed -> Error(InvalidTransition)
    Claimed(_) ->
      complete_task_for_claimed(db, task_id, user_id, org_id, version, current)
  }
}

fn complete_task_for_claimed(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  case task_state.claimed_by(current.state) {
    Some(id) if id == user_id ->
      complete_task_for_owner(db, task_id, user_id, org_id, version, current)
    _ -> Error(NotAuthorized)
  }
}

fn complete_task_for_owner(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  version: Int,
  current: task_mappers.Task,
) -> Result(Response, Error) {
  let _ =
    work_sessions_db.close_session_for_task(
      db,
      user_id,
      task_id,
      "task_completed",
    )

  case tasks_queries.complete_task(db, org_id, task_id, user_id, version) {
    Ok(task) ->
      complete_task_success(db, task_id, user_id, org_id, current, task)
    Error(service_error.NotFound) -> Error(VersionConflict)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))
  }
}

fn complete_task_success(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  org_id: Int,
  current: task_mappers.Task,
  task: task_mappers.Task,
) -> Result(Response, Error) {
  let ctx =
    rules_engine.TaskContext(
      task_id,
      current.project_id,
      org_id,
      current.type_id,
      current.card_id,
    )
  let from_state = task_status_to_string(current.status)
  let to_state = task_status_to_string(task.status)
  let _ = evaluate_task_rules(db, ctx, user_id, from_state, to_state)

  let _ = recompute_milestone_if_needed(db, task_id)

  let _ =
    maybe_evaluate_card_rules(
      db,
      current.card_id,
      current.project_id,
      org_id,
      user_id,
    )
  Ok(TaskResult(task))
}

fn recompute_milestone_if_needed(db: pog.Connection, task_id: Int) -> Nil {
  case milestones_db.get_effective_milestone_for_task(db, task_id) {
    Ok(Some(milestone_id)) -> {
      let _ = milestones_db.recompute_completion(db, milestone_id)
      Nil
    }
    _ -> Nil
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
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(service_error.NotFound) -> Error(NotFound)
    Error(service_error.DbError(e)) -> Error(DbError(e))
    Error(service_error.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(service_error.InvalidReference(_)) ->
      Error(ValidationError("Invalid reference"))
    Error(service_error.Unexpected(_)) ->
      Error(ValidationError("Unexpected error"))
    Error(service_error.Conflict(_)) -> Error(ValidationError("Conflict"))
    Error(service_error.AlreadyExists) -> Error(ValidationError("Conflict"))

    Ok(current) -> conflict_from_task(current)
  }
}

fn conflict_from_task(current: task_mappers.Task) -> Result(Response, Error) {
  case current.status {
    Claimed(_) ->
      Error(ClaimOwnershipConflict(task_state.claimed_by(current.state)))
    _ -> Error(VersionConflict)
  }
}

// =============================================================================
// Rules Engine Integration
// =============================================================================

/// Evaluate task rules after a state change.
/// This is a fire-and-forget call - errors are silently ignored to not block
/// the main operation.
fn evaluate_task_rules(
  db: pog.Connection,
  ctx: rules_engine.TaskContext,
  user_id: Int,
  from_state: String,
  to_state: String,
) -> Nil {
  let event = rules_engine.task_event(ctx, user_id, Some(from_state), to_state)
  // Fire and forget - don't block on rules engine
  let _ = rules_engine.evaluate_rules(db, event)
  Nil
}

/// Evaluate task rules for a newly created task (null → available).
fn evaluate_task_rules_created(
  db: pog.Connection,
  ctx: rules_engine.TaskContext,
  user_id: Int,
) -> Nil {
  let event = rules_engine.task_event(ctx, user_id, None, "available")
  // Fire and forget - don't block on rules engine
  let _ = rules_engine.evaluate_rules(db, event)
  Nil
}

/// Evaluate card rules if task belongs to a card and its state might have changed.
/// Card states: pendiente (no progress), en_curso (some progress), cerrada (all complete)
fn maybe_evaluate_card_rules(
  db: pog.Connection,
  card_id: Option(Int),
  project_id: Int,
  org_id: Int,
  user_id: Int,
) -> Nil {
  case card_id {
    None -> Nil
    Some(cid) ->
      evaluate_card_rules_for_task(db, cid, project_id, org_id, user_id)
  }
}

fn evaluate_card_rules_for_task(
  db: pog.Connection,
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
) -> Nil {
  case cards_db.get_card(db, card_id, user_id) {
    Error(_) -> Nil
    Ok(card) -> {
      let state = cards_db.state_to_string(card.state)

      let event =
        rules_engine.card_event(
          card_id,
          project_id,
          org_id,
          user_id,
          None,
          state,
        )

      let _ = rules_engine.evaluate_rules(db, event)
      Nil
    }
  }
}
