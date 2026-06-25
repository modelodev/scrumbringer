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
import domain/task_status.{Available, Claimed, Done}
import gleam/option.{type Option, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/service_error_response
import scrumbringer_server/repository/tasks/queries as tasks_queries
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
      case domain_task.status(current), current.blocked_count {
        Claimed(_), _ ->
          api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
        Done, _ -> api.error(422, "VALIDATION_ERROR", "Invalid transition")
        Available, count if count > 0 ->
          api.error(409, "CONFLICT_BLOCKED", "Task has incomplete dependencies")
        Available, _ -> api.error(409, "CONFLICT_VERSION", "Version conflict")
      }
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
      case domain_task.status(current) {
        Claimed(_) ->
          claimed_conflict_response(
            task_state.claimed_by(current.state),
            user_id,
          )
        Available | Done ->
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
