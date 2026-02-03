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

import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/json
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

/// Claims a task for the current user.
///
/// Example:
///   handle_task_claim(req, ctx, "10")
pub fn handle_task_claim(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> claim_for_user(req, ctx, user, task_id)
  }
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
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> release_for_user(req, ctx, user, task_id)
  }
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
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> complete_for_user(req, ctx, user, task_id)
  }
}

fn claim_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> claim_with_task_id(req, ctx, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn claim_with_task_id(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp

    Ok(task_id) -> {
      use data <- wisp.require_json(req)

      case decode_version(data) {
        Error(resp) -> resp
        Ok(version) -> claim_with_version(ctx, user, task_id, version)
      }
    }
  }
}

fn claim_with_version(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
  case
    workflow.handle(
      db,
      workflow_types.ClaimTask(task_id, user.id, user.org_id, version),
    )
  {
    Ok(workflow_types.TaskResult(task)) ->
      api.ok(json.object([#("task", presenters.task_json(task))]))

    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(workflow_types.AlreadyClaimed) ->
      api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
    Error(workflow_types.InvalidTransition) ->
      api.error(422, "VALIDATION_ERROR", "Invalid transition")
    Error(workflow_types.ClaimOwnershipConflict(_)) ->
      api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
    Error(workflow_types.VersionConflict) ->
      conflict_handlers.handle_claim_conflict(db, task_id, user.id)
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn release_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> release_with_task_id(req, ctx, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn release_with_task_id(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp

    Ok(task_id) -> {
      use data <- wisp.require_json(req)

      case decode_version(data) {
        Error(resp) -> resp
        Ok(version) -> release_with_version(ctx, user, task_id, version)
      }
    }
  }
}

fn release_with_version(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
  case
    workflow.handle(
      db,
      workflow_types.ReleaseTask(task_id, user.id, user.org_id, version),
    )
  {
    Ok(workflow_types.TaskResult(task)) ->
      api.ok(json.object([#("task", presenters.task_json(task))]))

    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(workflow_types.NotAuthorized) ->
      api.error(403, "FORBIDDEN", "Forbidden")
    Error(workflow_types.InvalidTransition) ->
      api.error(422, "VALIDATION_ERROR", "Invalid transition")
    Error(workflow_types.VersionConflict) ->
      conflict_handlers.handle_version_or_claim_conflict(db, task_id, user.id)
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn complete_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> complete_with_task_id(req, ctx, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn complete_with_task_id(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp

    Ok(task_id) -> {
      use data <- wisp.require_json(req)

      case decode_version(data) {
        Error(resp) -> resp
        Ok(version) -> complete_with_version(ctx, user, task_id, version)
      }
    }
  }
}

fn complete_with_version(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
  case
    workflow.handle(
      db,
      workflow_types.CompleteTask(task_id, user.id, user.org_id, version),
    )
  {
    Ok(workflow_types.TaskResult(task)) ->
      api.ok(json.object([#("task", presenters.task_json(task))]))

    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(workflow_types.NotAuthorized) ->
      api.error(403, "FORBIDDEN", "Forbidden")
    Error(workflow_types.InvalidTransition) ->
      api.error(422, "VALIDATION_ERROR", "Invalid transition")
    Error(workflow_types.VersionConflict) ->
      conflict_handlers.handle_version_or_claim_conflict(db, task_id, user.id)
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn decode_version(data: dynamic.Dynamic) -> Result(Int, wisp.Response) {
  let decoder = {
    use version <- decode.field("version", decode.int)
    decode.success(version)
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(version) -> Ok(version)
  }
}

fn parse_task_id(task_id: String) -> Result(Int, wisp.Response) {
  case int.parse(task_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}
