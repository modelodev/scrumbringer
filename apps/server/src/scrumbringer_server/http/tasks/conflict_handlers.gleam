//// Task conflict handling functions for Scrumbringer server.
////
//// ## Mission
////
//// Provides error response generation for task state conflicts including
//// claim conflicts and version conflicts.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_server/http/tasks/conflict_handlers
////
//// conflict_handlers.handle_claim_conflict(db, task_id, user_id)
//// conflict_handlers.handle_version_or_claim_conflict(db, task_id, user_id)
//// ```

import domain/task as domain_task
import domain/task/state as task_state
import gleam/option.{type Option, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/service_error_response
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/workflows/claimable_task
import wisp

// =============================================================================
// Conflict Handlers
// =============================================================================

/// Handle claim conflict: determine specific error based on current state.
///
/// ## Example
///
/// ```gleam
/// case tasks_queries.claim_task(...) {
///   Error(service_error.NotFound) -> handle_claim_conflict(db, task_id, user_id)
///   ...
/// }
/// ```
pub fn handle_claim_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(error) -> service_error_response.to_database_response(error)

    Ok(current) ->
      case current.state, current.blocked_count {
        task_state.Claimed(..), _ ->
          api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
        task_state.Closed(..), _ ->
          api.error(422, "VALIDATION_ERROR", "Invalid transition")
        task_state.Available, count if count > 0 ->
          api.error(409, "CONFLICT_BLOCKED", "Task has open dependencies")
        task_state.Available, _ ->
          available_claim_conflict_response(db, current)
      }
  }
}

fn available_claim_conflict_response(
  db: pog.Connection,
  task: domain_task.Task,
) -> wisp.Response {
  case claimable_task.from_task(db, task) {
    Ok(_) -> api.error(409, "CONFLICT_VERSION", "Version conflict")
    Error(claimable_task.MissingCard)
    | Error(claimable_task.InactiveCardLineage) ->
      api.error(409, "TASK_CARD_NOT_ACTIVE", "Task card is not active")
    Error(claimable_task.DbError(_)) ->
      api.error(500, "DATABASE_ERROR", "Database error")
  }
}

/// Handle version or claim conflict: determine if version mismatch or lost claim.
///
/// ## Example
///
/// ```gleam
/// case tasks_queries.release_task(...) {
///   Error(service_error.NotFound) ->
///     handle_version_or_claim_conflict(db, task_id, user_id)
///   ...
/// }
/// ```
pub fn handle_version_or_claim_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(error) -> service_error_response.to_database_response(error)

    Ok(current) ->
      case current.state {
        task_state.Claimed(..) ->
          claimed_conflict_response(
            task_state.claimed_by(current.state),
            user_id,
          )
        task_state.Available | task_state.Closed(..) ->
          api.error(422, "VALIDATION_ERROR", "Invalid transition")
      }
  }
}

fn claimed_conflict_response(
  claimed_by: Option(Int),
  user_id: Int,
) -> wisp.Response {
  case claimed_by == Some(user_id) {
    True -> api.error(409, "CONFLICT_VERSION", "Version conflict")
    False -> api.error(403, "FORBIDDEN", "Forbidden")
  }
}
