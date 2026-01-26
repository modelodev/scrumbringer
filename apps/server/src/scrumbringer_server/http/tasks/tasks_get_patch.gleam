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
//// - Task persistence (see `services/workflows/handlers.gleam`)
//// - JSON presentation (see `http/tasks/presenters.gleam`)
////
//// ## Relations
////
//// - Uses `services/workflows/handlers` for task operations
//// - Uses `http/tasks/presenters` for response JSON

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{type Option, None}
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

/// Handle GET /api/tasks/:id.
/// Example: handle_task_get(req, ctx, task_id)
pub fn handle_task_get(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case get_task(req, ctx, task_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

/// Handle PATCH /api/tasks/:id.
/// Example: handle_task_patch(req, ctx, task_id)
pub fn handle_task_patch(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Patch)
  use data <- wisp.require_json(req)

  // Justified nested case: unwrap Result<Response, Response> into a Response.
  case update_task(req, ctx, task_id, data) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn get_task(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use task_id <- result.try(parse_task_id(task_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use response <- result.try(fetch_task(db, task_id, user.id))
  Ok(response)
}

fn update_task(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id_str: String,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_csrf(req))
  use task_id <- result.try(parse_task_id(task_id_str))
  use #(version, updates) <- result.try(decode_update_payload(data))
  let auth.Ctx(db: db, ..) = ctx
  use response <- result.try(update_task_in_workflow(
    db,
    task_id,
    user.id,
    version,
    updates,
  ))
  Ok(response)
}

fn fetch_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(wisp.Response, wisp.Response) {
  case workflow.handle(db, workflow_types.GetTask(task_id, user_id)) {
    Ok(workflow_types.TaskResult(task)) ->
      Ok(api.ok(json.object([#("task", presenters.task_json(task))])))
    Ok(_) -> Error(api.error(500, "INTERNAL", "Unexpected response"))
    Error(workflow_types.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(workflow_types.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Unexpected error"))
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
    Ok(workflow_types.TaskResult(task)) ->
      Ok(api.ok(json.object([#("task", presenters.task_json(task))])))
    Ok(_) -> Error(api.error(500, "INTERNAL", "Unexpected response"))
    Error(workflow_types.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(workflow_types.NotAuthorized) ->
      Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(workflow_types.VersionConflict) ->
      Ok(conflict_handlers.handle_version_or_claim_conflict(
        db,
        task_id,
        user_id,
      ))
    Error(workflow_types.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(workflow_types.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Unexpected error"))
  }
}

fn decode_update_payload(
  data: dynamic.Dynamic,
) -> Result(#(Int, workflow_types.TaskUpdates), wisp.Response) {
  let decoder = {
    use version <- decode.field("version", decode.int)
    use title <- decode.optional_field(
      "title",
      None,
      decode.optional(decode.string),
    )
    use description <- decode.optional_field(
      "description",
      None,
      decode.optional(decode.string),
    )
    use priority <- decode.optional_field(
      "priority",
      None,
      decode.optional(decode.int),
    )
    use type_id <- decode.optional_field(
      "type_id",
      None,
      decode.optional(decode.int),
    )
    decode.success(#(version, title, description, priority, type_id))
  }

  decode.run(data, decoder)
  |> result.map(build_updates)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn build_updates(
  payload: #(Int, Option(String), Option(String), Option(Int), Option(Int)),
) -> #(Int, workflow_types.TaskUpdates) {
  let #(version, title, description, priority, type_id) = payload

  #(
    version,
    workflow_types.TaskUpdates(
      title: workflow_types.field_update_from_option(title),
      description: workflow_types.field_update_from_option(description),
      priority: workflow_types.field_update_from_option(priority),
      type_id: workflow_types.field_update_from_option(type_id),
    ),
  )
}

fn require_current_user(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  case auth.require_current_user(req, ctx) {
    Ok(user) -> Ok(user)
    Error(_) ->
      Error(api.error(401, "AUTH_REQUIRED", "Authentication required"))
  }
}

fn require_csrf(req: wisp.Request) -> Result(Nil, wisp.Response) {
  case csrf.require_double_submit(req) {
    Ok(Nil) -> Ok(Nil)
    Error(_) ->
      Error(api.error(403, "FORBIDDEN", "CSRF token missing or invalid"))
  }
}

fn parse_task_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}
