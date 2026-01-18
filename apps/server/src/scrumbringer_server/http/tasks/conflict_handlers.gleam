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

import gleam/option.{Some}
import pog
import domain/task_status.{Available, Claimed, Completed}
import scrumbringer_server/http/api
import scrumbringer_server/persistence/tasks/queries as tasks_queries
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
///   Error(tasks_queries.NotFound) -> handle_claim_conflict(db, task_id, user_id)
///   ...
/// }
/// ```
pub fn handle_claim_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Error(tasks_queries.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")

    Ok(current) ->
      case current.status {
        Claimed(_) -> api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
        Completed -> api.error(422, "VALIDATION_ERROR", "Invalid transition")
        Available -> api.error(409, "CONFLICT_VERSION", "Version conflict")
      }
  }
}

/// Handle version or claim conflict: determine if version mismatch or lost claim.
///
/// ## Example
///
/// ```gleam
/// case tasks_queries.release_task(...) {
///   Error(tasks_queries.NotFound) ->
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
    Error(tasks_queries.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")

    Ok(current) ->
      case current.status {
        Claimed(_) ->
          case current.claimed_by {
            Some(id) if id == user_id ->
              api.error(409, "CONFLICT_VERSION", "Version conflict")
            _ -> api.error(403, "FORBIDDEN", "Forbidden")
          }

        Available | Completed ->
          api.error(422, "VALIDATION_ERROR", "Invalid transition")
      }
  }
}
