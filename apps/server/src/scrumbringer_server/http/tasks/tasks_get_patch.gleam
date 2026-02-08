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

import domain/field_update
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/metrics_db
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
  let include_metrics = wants_metrics(req)

  use <- wisp.require_method(req, http.Get)

  case get_task(req, ctx, task_id, include_metrics) {
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
  include_metrics: Bool,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use task_id <- result.try(parse_task_id(task_id_str))
  let auth.Ctx(db: db, ..) = ctx

  case include_metrics {
    True -> {
      use _ <- result.try(check_task_access(db, task_id, user.id))
      case metrics_db.get_task_metrics(db, task_id) {
        Ok(metrics) ->
          Ok(
            api.ok(
              json.object([
                #("id", json.string(int.to_string(task_id))),
                #("metrics", task_metrics_json(metrics)),
              ]),
            ),
          )
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
    Ok(workflow_types.TaskResult(_)) -> Ok(Nil)
    Ok(_) -> Error(api.error(500, "internal", "Unexpected response"))
    Error(workflow_types.NotFound) ->
      Error(api.error(404, "not_found", "Not found"))
    Error(workflow_types.NotAuthorized) ->
      Error(api.error(403, "forbidden", "Forbidden"))
    Error(workflow_types.DbError(_)) ->
      Error(api.error(500, "internal", "Database error"))
    Error(_) -> Error(api.error(500, "internal", "Unexpected error"))
  }
}

fn update_task(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id_str: String,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
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
    Error(workflow_types.TaskMilestoneInheritedFromCard) ->
      Error(api.error(
        422,
        "TASK_MILESTONE_INHERITED_FROM_CARD",
        "Task milestone is inherited from card",
      ))
    Error(workflow_types.InvalidMovePoolToMilestone) ->
      Error(api.error(
        422,
        "INVALID_MOVE_POOL_TO_MILESTONE",
        "Invalid move from pool to milestone",
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

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(payload) ->
      case decode_milestone_update(data) {
        Error(resp) -> Error(resp)
        Ok(milestone_update) -> Ok(build_updates(payload, milestone_update))
      }
  }
}

fn build_updates(
  payload: #(Int, Option(String), Option(String), Option(Int), Option(Int)),
  milestone_update: field_update.FieldUpdate(Option(Int)),
) -> #(Int, workflow_types.TaskUpdates) {
  let #(version, title, description, priority, type_id) = payload

  #(
    version,
    workflow_types.TaskUpdates(
      title: field_update.from_option(title),
      description: field_update.from_option(description),
      priority: field_update.from_option(priority),
      type_id: field_update.from_option(type_id),
      milestone_id: milestone_update,
    ),
  )
}

fn decode_milestone_update(
  data: dynamic.Dynamic,
) -> Result(field_update.FieldUpdate(Option(Int)), wisp.Response) {
  case
    decode.run(
      data,
      decode.field("milestone_id", decode.dynamic, decode.success),
    )
  {
    Error(_) -> Ok(field_update.unchanged())
    Ok(raw) ->
      case decode.run(raw, decode.optional(decode.int)) {
        Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
        Ok(value) -> Ok(field_update.set(normalize_milestone_id(value)))
      }
  }
}

fn normalize_milestone_id(value: Option(Int)) -> Option(Int) {
  case value {
    Some(id) if id <= 0 -> None
    _ -> value
  }
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

fn parse_task_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn wants_metrics(req: wisp.Request) -> Bool {
  wisp.get_query(req)
  |> list.any(fn(pair) { pair.0 == "include" && pair.1 == "metrics" })
}

fn task_metrics_json(metrics: metrics_db.TaskMetrics) -> json.Json {
  let metrics_db.TaskMetrics(
    claim_count: claim_count,
    release_count: release_count,
    unique_executors: unique_executors,
    first_claim_at: first_claim_at,
    current_state_duration_s: current_state_duration_s,
    pool_lifetime_s: pool_lifetime_s,
    session_count: session_count,
    total_work_time_s: total_work_time_s,
  ) = metrics

  json.object([
    #("claim_count", json.int(claim_count)),
    #("release_count", json.int(release_count)),
    #("unique_executors", json.int(unique_executors)),
    #("first_claim_at", option_string_json(first_claim_at)),
    #("current_state_duration_s", json.int(current_state_duration_s)),
    #("pool_lifetime_s", json.int(pool_lifetime_s)),
    #("session_count", json.int(session_count)),
    #("total_work_time_s", json.int(total_work_time_s)),
  ])
}

fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.string(v)
  }
}
