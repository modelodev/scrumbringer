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

import domain/task_status.{Available, Claimed, Completed, task_status_to_string}
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/cards_db
import scrumbringer_server/services/rules_engine
import scrumbringer_server/services/rules_target
import scrumbringer_server/services/task_types_db
import scrumbringer_server/services/work_sessions_db
import scrumbringer_server/services/workflows/authorization
import scrumbringer_server/services/workflows/types.{
  type Error, type Message, type Response, type TaskFilters, type TaskUpdates,
  AlreadyClaimed, ClaimOwnershipConflict, ClaimTask, CompleteTask, CreateTask,
  CreateTaskType, DbError, DeleteTaskType, GetTask, InvalidTransition,
  ListTaskTypes, ListTasks, NotAuthorized, NotFound, ReleaseTask, TaskResult,
  TaskTypeAlreadyExists, TaskTypeCreated, TaskTypeDeleted, TaskTypeInUse,
  TaskTypeUpdated, TaskTypesList, TasksList, UpdateTask, UpdateTaskType,
  ValidationError, VersionConflict, field_update_to_option,
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
      project_id,
      user_id,
      org_id,
      title,
      description,
      priority,
      type_id,
      card_id,
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
    Error(task_types_db.AlreadyExists) -> Error(TaskTypeAlreadyExists)
    Error(task_types_db.InvalidCapabilityId) ->
      Error(ValidationError("Invalid capability_id"))
    Error(task_types_db.DbError(e)) -> Error(DbError(e))
    Error(task_types_db.NoRowReturned) ->
      Error(ValidationError("Failed to create task type"))
  }
}

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
        Error(task_types_db.UpdateNotFound) -> Error(NotFound)
        Error(task_types_db.UpdateDbError(e)) -> Error(DbError(e))
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
    Error(task_types_db.DeleteHasTasks) -> Error(TaskTypeInUse)
    Error(task_types_db.DeleteNotFound) -> Error(NotFound)
    Error(task_types_db.DeleteDbError(e)) -> Error(DbError(e))
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
  card_id: Int,
) -> Result(Response, Error) {
  use _ <- authorization.require_project_member(db, project_id, user_id)
  use validated_title <- validation.validate_task_title(title)
  use _ <- validation.validate_priority(priority)
  use _ <- validation.validate_task_type_in_project(db, type_id, project_id)

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
    )
  {
    Ok(task) -> {
      // Trigger rules engine for task creation (null → available)
      let card_id_opt = case card_id {
        id if id > 0 -> Some(id)
        _ -> None
      }
      let ctx =
        rules_engine.TaskContext(
          task.id,
          project_id,
          org_id,
          type_id,
          card_id_opt,
        )
      let _ = evaluate_task_rules_created(db, ctx, user_id)
      Ok(TaskResult(task))
    }
    Error(tasks_queries.InvalidTypeId) ->
      Error(ValidationError("Invalid type_id"))
    Error(tasks_queries.InvalidCardId) ->
      Error(ValidationError("Invalid card_id"))
    Error(tasks_queries.CreateDbError(e)) -> Error(DbError(e))
  }
}

fn handle_get_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Response, Error) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(TaskResult(task))
    Error(tasks_queries.NotFound) -> Error(NotFound)
    Error(tasks_queries.DbError(e)) -> Error(DbError(e))
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
    Error(tasks_queries.NotFound) -> Error(NotFound)
    Error(tasks_queries.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Available | Completed -> Error(NotAuthorized)

        Claimed(_) ->
          case current.claimed_by {
            Some(id) if id == user_id -> {
              use _ <- validation.validate_type_update(
                db,
                updates.type_id,
                current.project_id,
              )

              let title_update = field_update_to_option(updates.title)
              let description_update =
                field_update_to_option(updates.description)
              let priority_update = field_update_to_option(updates.priority)
              let type_id_update = field_update_to_option(updates.type_id)

              case
                tasks_queries.update_task_claimed_by_user(
                  db,
                  task_id,
                  user_id,
                  title_update,
                  description_update,
                  priority_update,
                  type_id_update,
                  version,
                )
              {
                Ok(task) -> Ok(TaskResult(task))
                Error(tasks_queries.NotFound) -> Error(VersionConflict)
                Error(tasks_queries.DbError(e)) -> Error(DbError(e))
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
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(tasks_queries.NotFound) -> Error(NotFound)
    Error(tasks_queries.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Claimed(_) -> Error(AlreadyClaimed)
        Completed -> Error(InvalidTransition)

        Available ->
          case tasks_queries.claim_task(db, org_id, task_id, user_id, version) {
            Ok(task) -> {
              // Trigger rules engine for task state change
              let ctx =
                rules_engine.TaskContext(
                  task_id,
                  current.project_id,
                  org_id,
                  current.type_id,
                  current.card_id,
                )
              let from_state =
                rules_target.task_state(task_status_to_string(current.status))
              let to_state =
                rules_target.task_state(task_status_to_string(task.status))
              let _ =
                evaluate_task_rules(db, ctx, user_id, from_state, to_state)

              // Check for card state change if task belongs to a card
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
            Error(tasks_queries.NotFound) ->
              detect_conflict(db, task_id, user_id)
            Error(tasks_queries.DbError(e)) -> Error(DbError(e))
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
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(tasks_queries.NotFound) -> Error(NotFound)
    Error(tasks_queries.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Available | Completed -> Error(InvalidTransition)

        Claimed(_) ->
          case current.claimed_by {
            Some(id) if id == user_id -> {
              // Close any active work session before releasing
              let _ =
                work_sessions_db.close_session_for_task(
                  db,
                  user_id,
                  task_id,
                  "task_released",
                )

              case
                tasks_queries.release_task(
                  db,
                  org_id,
                  task_id,
                  user_id,
                  version,
                )
              {
                Ok(task) -> {
                  // Trigger rules engine for task state change
                  let ctx =
                    rules_engine.TaskContext(
                      task_id,
                      current.project_id,
                      org_id,
                      current.type_id,
                      current.card_id,
                    )
                  let from_state =
                    rules_target.task_state(task_status_to_string(
                      current.status,
                    ))
                  let to_state =
                    rules_target.task_state(task_status_to_string(task.status))
                  let _ =
                    evaluate_task_rules(db, ctx, user_id, from_state, to_state)

                  // Check for card state change if task belongs to a card
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
                Error(tasks_queries.NotFound) -> Error(VersionConflict)
                Error(tasks_queries.DbError(e)) -> Error(DbError(e))
              }
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
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(tasks_queries.NotFound) -> Error(NotFound)
    Error(tasks_queries.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Available | Completed -> Error(InvalidTransition)

        Claimed(_) ->
          case current.claimed_by {
            Some(id) if id == user_id -> {
              // Close any active work session before completing
              let _ =
                work_sessions_db.close_session_for_task(
                  db,
                  user_id,
                  task_id,
                  "task_completed",
                )

              case
                tasks_queries.complete_task(
                  db,
                  org_id,
                  task_id,
                  user_id,
                  version,
                )
              {
                Ok(task) -> {
                  // Trigger rules engine for task state change
                  let ctx =
                    rules_engine.TaskContext(
                      task_id,
                      current.project_id,
                      org_id,
                      current.type_id,
                      current.card_id,
                    )
                  let from_state =
                    rules_target.task_state(task_status_to_string(
                      current.status,
                    ))
                  let to_state =
                    rules_target.task_state(task_status_to_string(task.status))
                  let _ =
                    evaluate_task_rules(db, ctx, user_id, from_state, to_state)

                  // Check for card state change if task belongs to a card
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
                Error(tasks_queries.NotFound) -> Error(VersionConflict)
                Error(tasks_queries.DbError(e)) -> Error(DbError(e))
              }
            }

            _ -> Error(NotAuthorized)
          }
      }
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
    Error(tasks_queries.NotFound) -> Error(NotFound)
    Error(tasks_queries.DbError(e)) -> Error(DbError(e))

    Ok(current) ->
      case current.status {
        Claimed(_) -> Error(ClaimOwnershipConflict(current.claimed_by))
        _ -> Error(VersionConflict)
      }
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
  from_state: rules_target.TaskState,
  to_state: rules_target.TaskState,
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
  let event =
    rules_engine.task_event(
      ctx,
      user_id,
      None,
      rules_target.task_state("available"),
    )
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
    Some(cid) -> {
      // Get current card state after task change
      case cards_db.get_card(db, cid) {
        Error(_) -> Nil
        Ok(card) -> {
          // Derive current state string
          let state =
            rules_target.card_state(cards_db.state_to_string(card.state))

          // We evaluate rules for the current state
          // The rules engine tracks idempotency per (rule, card, state)
          let event =
            rules_engine.card_event(cid, project_id, org_id, user_id, state)

          let _ = rules_engine.evaluate_rules(db, event)
          Nil
        }
      }
    }
  }
}
