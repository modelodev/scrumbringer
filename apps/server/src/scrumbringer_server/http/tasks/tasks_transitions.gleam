//// Task state transition HTTP handler helpers.
////
//// ## Mission
////
//// Provide claim, release, and complete endpoints for tasks.
////
//// ## Responsibilities
////
//// - Parse route params and JSON payloads
//// - Authorize current user and CSRF
//// - Map workflow results into HTTP responses
////
//// ## Non-responsibilities
////
//// - Task persistence (see `services/workflows/handlers.gleam`)
//// - Conflict detection logic (see `http/tasks/conflict_handlers.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for user identity
//// - Uses workflow handlers for domain transitions

import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/payload_responses
import scrumbringer_server/http/tasks/payloads
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

type Transition {
  Claim
  Release
  Complete
}

/// Claims a task for the current user.
///
/// Example:
///   handle_task_claim(req, ctx, "10")
pub fn handle_task_claim(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  handle_transition(req, ctx, task_id, Claim)
}

/// Releases a task claim for the current user.
///
/// Example:
///   handle_task_release(req, ctx, "10")
pub fn handle_task_release(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  handle_transition(req, ctx, task_id, Release)
}

/// Completes a task for the current user.
///
/// Example:
///   handle_task_complete(req, ctx, "10")
pub fn handle_task_complete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  handle_transition(req, ctx, task_id, Complete)
}

fn handle_transition(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  transition: Transition,
) -> wisp.Response {
  with_transition_payload(req, ctx, task_id, fn(user, task_id, payload) {
    transition_payload(ctx, user, task_id, transition, payload)
  })
}

fn require_transition_context(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> Result(#(StoredUser, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use task_id <- result.try(api.parse_id(task_id))

  Ok(#(user, task_id))
}

fn transition_payload(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  transition: Transition,
  payload: payloads.VersionPayload,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  let payloads.VersionPayload(version: version) = payload

  case
    workflow.handle(db, transition_message(transition, user, task_id, version))
  {
    Ok(response) -> transition_response(response)
    Error(error) ->
      Error(transition_error_response(transition, error, db, task_id, user.id))
  }
}

fn with_transition_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  handle_payload: fn(StoredUser, Int, payloads.VersionPayload) ->
    Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case require_transition_context(req, ctx, task_id) {
    Error(resp) -> resp
    Ok(#(user, task_id)) -> {
      use data <- wisp.require_json(req)
      case decode_version(data) {
        Error(resp) -> resp
        Ok(payload) ->
          case handle_payload(user, task_id, payload) {
            Ok(resp) -> resp
            Error(resp) -> resp
          }
      }
    }
  }
}

fn transition_message(
  transition: Transition,
  user: StoredUser,
  task_id: Int,
  version: Int,
) -> workflow_types.Message {
  case transition {
    Claim -> workflow_types.ClaimTask(task_id, user.id, user.org_id, version)
    Release ->
      workflow_types.ReleaseTask(task_id, user.id, user.org_id, version)
    Complete ->
      workflow_types.CompleteTask(task_id, user.id, user.org_id, version)
  }
}

fn transition_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TaskResult(task) ->
      Ok(api.ok(presenters.task_response(task)))
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TasksList(_) -> Error(unexpected_response())
  }
}

fn transition_error_response(
  transition: Transition,
  error: workflow_types.Error,
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case transition {
    Claim -> claim_error_response(error, db, task_id, user_id)
    Release -> release_or_complete_error_response(error, db, task_id, user_id)
    Complete -> release_or_complete_error_response(error, db, task_id, user_id)
  }
}

fn claim_error_response(
  error: workflow_types.Error,
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case error {
    workflow_types.NotFound -> not_found_response()
    workflow_types.AlreadyClaimed -> claimed_conflict_response()
    workflow_types.InvalidTransition -> invalid_transition_response()
    workflow_types.ClaimOwnershipConflict(_) -> claimed_conflict_response()
    workflow_types.VersionConflict ->
      conflict_handlers.handle_claim_conflict(db, task_id, user_id)
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.NotAuthorized
    | workflow_types.ValidationError(_)
    | workflow_types.TaskMilestoneInheritedFromCard
    | workflow_types.InvalidMovePoolToMilestone
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse -> unexpected_error()
  }
}

fn release_or_complete_error_response(
  error: workflow_types.Error,
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case error {
    workflow_types.NotFound -> not_found_response()
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.InvalidTransition -> invalid_transition_response()
    workflow_types.VersionConflict ->
      conflict_handlers.handle_version_or_claim_conflict(db, task_id, user_id)
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.ValidationError(_)
    | workflow_types.TaskMilestoneInheritedFromCard
    | workflow_types.InvalidMovePoolToMilestone
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn decode_version(data) -> Result(payloads.VersionPayload, wisp.Response) {
  payloads.decode_version(data)
  |> result.map_error(payload_responses.decode_error)
}

fn claimed_conflict_response() -> wisp.Response {
  api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
}

fn invalid_transition_response() -> wisp.Response {
  api.error(422, "VALIDATION_ERROR", "Invalid transition")
}

fn forbidden_response() -> wisp.Response {
  api.error(403, "FORBIDDEN", "Forbidden")
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}

fn unexpected_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Unexpected response")
}

fn unexpected_error() -> wisp.Response {
  api.error(500, "INTERNAL", "Unexpected error")
}
