//// HTTP handlers for task position management (kanban ordering).
////
//// ## Mission
////
//// Provides endpoints for retrieving and updating task positions on boards.
////
//// ## Responsibilities
////
//// - List task positions for the current user
//// - Update task positions when cards are moved
//// - Validate task access before position changes
////
//// ## Non-responsibilities
////
//// - Task membership rules (see `services/projects_db.gleam`)
//// - Persistence of positions (see `services/task_positions_db.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for session identity
//// - Uses `persistence/tasks/queries.gleam` for access checks

import gleam/http
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/service_error_response
import scrumbringer_server/http/task_positions/payloads as position_payloads
import scrumbringer_server/http/task_positions/presenters as position_presenters
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/task_positions_db
import wisp

/// Returns task positions for the current user.
///
/// Example:
///   handle_me_task_positions(req, ctx)
pub fn handle_me_task_positions(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> handle_positions_for_user(req, ctx, user)
  }
}

/// Updates a task position for the current user.
///
/// Example:
///   handle_me_task_position(req, ctx, "123")
pub fn handle_me_task_position(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> update_position_for_user(req, ctx, user, task_id)
  }
}

fn handle_positions_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  let query = wisp.get_query(req)

  case positions_payload(ctx, user.id, query) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn positions_payload(
  ctx: auth.Ctx,
  user_id: Int,
  query: List(#(String, String)),
) -> Result(wisp.Response, wisp.Response) {
  use project_id <- result.try(parse_project_id_filter(query))
  use positions <- result.try(list_positions_for_user(ctx, user_id, project_id))
  Ok(api.ok(position_presenters.positions_response(positions)))
}

fn list_positions_for_user(
  ctx: auth.Ctx,
  user_id: Int,
  project_id: Int,
) -> Result(List(task_positions_db.TaskPosition), wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  case project_id {
    0 -> fetch_positions(db, user_id, project_id)
    _ -> {
      use _ <- result.try(require_project_member(db, project_id, user_id))
      fetch_positions(db, user_id, project_id)
    }
  }
}

fn fetch_positions(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Result(List(task_positions_db.TaskPosition), wisp.Response) {
  case task_positions_db.list_positions_for_user(db, user_id, project_id) {
    Ok(positions) -> Ok(positions)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn update_position_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> update_position_with_task(req, ctx, user, task_id)
  }
}

fn update_position_with_task(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case api.parse_id(task_id) {
    Error(resp) -> resp

    Ok(task_id) -> update_position(req, ctx, user, task_id)
  }
}

fn update_position(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  let auth.Ctx(db: db, ..) = ctx

  case
    update_position_payload(
      fn() { decode_position_payload(data) },
      db,
      user,
      task_id,
    )
  {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn update_position_payload(
  decode_payload: fn() ->
    Result(position_payloads.PositionPayload, wisp.Response),
  db: pog.Connection,
  user: StoredUser,
  task_id: Int,
) -> Result(wisp.Response, wisp.Response) {
  use _ <- result.try(require_task_access(db, task_id, user.id))
  use payload <- result.try(decode_payload())
  let position_payloads.PositionPayload(x: x, y: y) = payload
  use position <- result.try(upsert_position(db, task_id, user.id, x, y))
  Ok(api.ok(position_presenters.position_response(position)))
}

fn decode_position_payload(
  data,
) -> Result(position_payloads.PositionPayload, wisp.Response) {
  position_payloads.decode_position(data)
  |> result.map_error(position_payload_error_to_response)
}

fn position_payload_error_to_response(
  error: position_payloads.DecodeError,
) -> wisp.Response {
  case error {
    position_payloads.InvalidJson ->
      api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  }
}

fn upsert_position(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  x: Int,
  y: Int,
) -> Result(task_positions_db.TaskPosition, wisp.Response) {
  case task_positions_db.upsert_position(db, task_id, user_id, x, y) {
    Ok(position) -> Ok(position)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn parse_project_id_filter(
  query: List(#(String, String)),
) -> Result(Int, wisp.Response) {
  position_payloads.parse_project_id_filter(query)
  |> result.map_error(project_filter_error_to_response)
}

fn project_filter_error_to_response(
  error: position_payloads.ProjectFilterError,
) -> wisp.Response {
  case error {
    position_payloads.InvalidProjectId ->
      api.error(422, "VALIDATION_ERROR", "Invalid project_id")
  }
}

fn require_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_member(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(database_error_response())
  }
}

fn require_task_access(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
