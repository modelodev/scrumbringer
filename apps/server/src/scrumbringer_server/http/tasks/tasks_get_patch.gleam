//// Task get and patch HTTP handler helpers.
////
//// ## Mission
////
//// Provide GET and PATCH endpoints for task resources.
////
//// ## Responsibilities
////
//// - Authenticate and authorize access
//// - Parse task identifiers and update payloads
//// - Delegate task operations to workflow handlers
////
//// ## Non-responsibilities
////
//// - Task repository (see `use_case/workflows/handlers.gleam`)
//// - JSON presentation (see `http/tasks/presenters.gleam`)
////
//// ## Relations
////
//// - Uses `use_case/workflows/handlers` for task operations
//// - Uses `http/tasks/presenters` for response JSON

import gleam/http
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/http/query
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/payload_responses
import scrumbringer_server/http/tasks/payloads
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/use_case/metrics_db
import scrumbringer_server/use_case/workflows/handlers as workflow
import scrumbringer_server/use_case/workflows/types as workflow_types
import wisp

/// Handle GET /api/tasks/:id.
/// Example: handle_task_get(req, ctx, task_id)
pub fn handle_task_get(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  let include_metrics = wants_metrics(req)

  use <- wisp.require_method(req, http.Get)

  response_from_result(get_task(req, ctx, task_id, include_metrics))
}

/// Handle PATCH /api/tasks/:id.
/// Example: handle_task_patch(req, ctx, task_id)
pub fn handle_task_patch(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Patch)

  case require_update_task_access(req, ctx, task_id) {
    Error(resp) -> resp
    Ok(#(db, task_id, user_id)) ->
      json_payload.with_response(req, decode_update_payload, fn(payload) {
        response_from_result(update_task(db, task_id, user_id, payload))
      })
  }
}

/// Handle DELETE /api/tasks/:id.
/// Deletes only tasks without operational history.
pub fn handle_task_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Delete)

  case require_delete_task_access(req, ctx, task_id) {
    Error(resp) -> resp
    Ok(#(db, task_id, user_id)) ->
      response_from_result(delete_task(db, task_id, user_id))
  }
}

fn response_from_result(
  result: Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case result {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn get_task(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id_str: String,
  include_metrics: Bool,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use task_id <- result.try(api.parse_id(task_id_str))
  let auth.Ctx(db: db, ..) = ctx

  case include_metrics {
    True -> {
      use _ <- result.try(check_task_access(db, task_id, user.id))
      case metrics_db.get_task_metrics(db, task_id) {
        Ok(metrics) ->
          Ok(api.ok(presenters.task_metrics_response(task_id, metrics)))
        Error(metrics_db.NotFound) ->
          Error(api.error(404, "not_found", "Not found"))
        Error(metrics_db.MetricsUnavailable) ->
          Error(api.error(409, "metrics_unavailable", "Metrics unavailable"))
        Error(metrics_db.DbError(_)) ->
          Error(api.error(500, "internal", "Database error"))
      }
    }
    False -> {
      use response <- result.try(fetch_task(db, task_id, user.id))
      Ok(response)
    }
  }
}

fn check_task_access(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case workflow.handle(db, workflow_types.GetTask(task_id, user_id)) {
    Ok(response) -> check_task_access_response(response)
    Error(error) -> Error(check_task_access_error_response(error))
  }
}

fn require_update_task_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id_str: String,
) -> Result(#(pog.Connection, Int, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
  use task_id <- result.try(api.parse_id(task_id_str))
  let auth.Ctx(db: db, ..) = ctx
  Ok(#(db, task_id, user.id))
}

fn require_delete_task_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id_str: String,
) -> Result(#(pog.Connection, Int, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
  use task_id <- result.try(api.parse_id(task_id_str))
  let auth.Ctx(db: db, ..) = ctx
  Ok(#(db, task_id, user.id))
}

fn update_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  payload: payloads.UpdateTaskPayload,
) -> Result(wisp.Response, wisp.Response) {
  use response <- result.try(update_task_in_workflow(
    db,
    task_id,
    user_id,
    payload.version,
    payload.updates,
  ))
  Ok(response)
}

fn fetch_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(wisp.Response, wisp.Response) {
  case workflow.handle(db, workflow_types.GetTask(task_id, user_id)) {
    Ok(response) -> task_response(response)
    Error(error) -> Error(fetch_task_error_response(error))
  }
}

fn delete_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(wisp.Response, wisp.Response) {
  case workflow.handle(db, workflow_types.DeleteTask(task_id, user_id)) {
    Ok(response) -> delete_task_response(response)
    Error(error) -> Error(delete_task_error_response(error))
  }
}

fn update_task_in_workflow(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
  updates: workflow_types.TaskUpdates,
) -> Result(wisp.Response, wisp.Response) {
  case
    workflow.handle(
      db,
      workflow_types.UpdateTask(task_id, user_id, version, updates),
    )
  {
    Ok(response) -> task_response(response)
    Error(workflow_types.VersionConflict) ->
      Ok(conflict_handlers.handle_version_or_claim_conflict(
        db,
        task_id,
        user_id,
      ))
    Error(error) -> Error(update_task_error_response(error))
  }
}

fn check_task_access_response(
  response: workflow_types.Response,
) -> Result(Nil, wisp.Response) {
  case response {
    workflow_types.TaskResult(_) -> Ok(Nil)
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TasksList(_) -> Error(lower_unexpected_response())
  }
}

fn check_task_access_error_response(
  error: workflow_types.Error,
) -> wisp.Response {
  case error {
    workflow_types.NotFound -> lower_not_found_response()
    workflow_types.NotAuthorized -> lower_forbidden_response()
    workflow_types.DbError(_) -> lower_database_error_response()
    workflow_types.ValidationError(_)
    | workflow_types.TaskParentCardInheritedFromCard
    | workflow_types.CardHasChildCards
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> lower_unexpected_error()
  }
}

fn task_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TaskResult(task) ->
      Ok(api.ok(presenters.task_response(task)))
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TasksList(_) -> Error(unexpected_response())
  }
}

fn delete_task_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TaskDeleted(_) -> Ok(api.no_content())
    workflow_types.TaskResult(_)
    | workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TasksList(_) -> Error(unexpected_response())
  }
}

fn fetch_task_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotFound -> not_found_response()
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.NotAuthorized
    | workflow_types.ValidationError(_)
    | workflow_types.TaskParentCardInheritedFromCard
    | workflow_types.CardHasChildCards
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn delete_task_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotFound -> not_found_response()
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.TaskHasOperationalHistory ->
      api.error(
        409,
        "TASK_HAS_OPERATIONAL_HISTORY",
        "Task has operational history and must be closed instead of deleted",
      )
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.ValidationError(_)
    | workflow_types.TaskParentCardInheritedFromCard
    | workflow_types.CardHasChildCards
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn update_task_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotFound -> not_found_response()
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.TaskParentCardInheritedFromCard ->
      api.error(
        422,
        "TASK_PARENT_CARD_CONFLICT",
        "Task cannot specify both card_id and parent_card_id",
      )
    workflow_types.InvalidMovePoolToParentCard ->
      api.error(
        422,
        "INVALID_MOVE_POOL_TO_PARENT_CARD",
        "Invalid move from pool to parent card",
      )
    workflow_types.ValidationError(message) ->
      api.error(422, "VALIDATION_ERROR", message)
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.CardHasChildCards
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
    workflow_types.VersionConflict -> unexpected_error()
  }
}

fn decode_update_payload(
  data,
) -> Result(payloads.UpdateTaskPayload, wisp.Response) {
  payloads.decode_update_task(data)
  |> result.map_error(payload_responses.decode_error)
}

fn wants_metrics(req: wisp.Request) -> Bool {
  query.has_value(wisp.get_query(req), "include", "metrics")
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn forbidden_response() -> wisp.Response {
  api.error(403, "FORBIDDEN", "Forbidden")
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

fn lower_not_found_response() -> wisp.Response {
  api.error(404, "not_found", "Not found")
}

fn lower_forbidden_response() -> wisp.Response {
  api.error(403, "forbidden", "Forbidden")
}

fn lower_database_error_response() -> wisp.Response {
  api.error(500, "internal", "Database error")
}

fn lower_unexpected_response() -> wisp.Response {
  api.error(500, "internal", "Unexpected response")
}

fn lower_unexpected_error() -> wisp.Response {
  api.error(500, "internal", "Unexpected error")
}
