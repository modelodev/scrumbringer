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

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> update_position_for_user(req, ctx, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn handle_positions_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  let query = wisp.get_query(req)

  case parse_project_id_filter(query) {
    Error(resp) -> resp

    Ok(project_id) ->
      case list_positions_for_user(ctx, user.id, project_id) {
        Ok(positions) ->
          api.ok(
            json.object([
              #("positions", json.array(positions, of: position_json)),
            ]),
          )

        Error(resp) -> resp
      }
  }
}

// Justification: nested case improves clarity for branching logic.
fn list_positions_for_user(
  ctx: auth.Ctx,
  user_id: Int,
  project_id: Int,
) -> Result(List(task_positions_db.TaskPosition), wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  case project_id {
    0 -> fetch_positions(db, user_id, project_id)
    _ -> {
      case require_project_member(db, project_id, user_id) {
        Error(resp) -> Error(resp)
        Ok(Nil) -> fetch_positions(db, user_id, project_id)
      }
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
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
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
  case parse_task_id(task_id) {
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
  let auth.Ctx(db: db, ..) = ctx

  case require_task_access(db, task_id, user.id) {
    Error(resp) -> resp

    Ok(Nil) -> update_position_with_payload(req, db, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn update_position_with_payload(
  req: wisp.Request,
  db: pog.Connection,
  user: StoredUser,
  task_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_position_payload(data) {
    Error(resp) -> resp
    Ok(#(x, y)) ->
      case upsert_position(db, task_id, user.id, x, y) {
        Ok(position) ->
          api.ok(json.object([#("position", position_json(position))]))
        Error(resp) -> resp
      }
  }
}

fn decode_position_payload(
  data: dynamic.Dynamic,
) -> Result(#(Int, Int), wisp.Response) {
  let decoder = {
    use x <- decode.field("x", decode.int)
    use y <- decode.field("y", decode.int)
    decode.success(#(x, y))
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(payload) -> Ok(payload)
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
    Error(task_positions_db.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(task_positions_db.UnexpectedEmptyResult) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}


fn parse_task_id(task_id: String) -> Result(Int, wisp.Response) {
  case int.parse(task_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

// Justification: nested case improves clarity for branching logic.
fn parse_project_id_filter(
  query: List(#(String, String)),
) -> Result(Int, wisp.Response) {
  case single_query_value(query, "project_id") {
    Ok(None) -> Ok(0)

    Ok(Some(value)) ->
      // Justification: nested case converts the parsed string into an ID.
      case int.parse(value) {
        Ok(id) -> Ok(id)
        Error(_) ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid project_id"))
      }

    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid project_id"))
  }
}

fn single_query_value(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(String), Nil) {
  let values =
    query
    |> list.filter_map(fn(pair) {
      case pair.0 == key {
        True -> Ok(pair.1)
        False -> Error(Nil)
      }
    })

  case values {
    [] -> Ok(None)
    [value] -> Ok(Some(value))
    _ -> Error(Nil)
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
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn require_task_access(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(_) -> Ok(Nil)
    Error(tasks_queries.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn position_json(position: task_positions_db.TaskPosition) -> json.Json {
  let task_positions_db.TaskPosition(
    task_id: task_id,
    user_id: user_id,
    x: x,
    y: y,
    updated_at: updated_at,
  ) = position

  json.object([
    #("task_id", json.int(task_id)),
    #("user_id", json.int(user_id)),
    #("x", json.int(x)),
    #("y", json.int(y)),
    #("updated_at", json.string(updated_at)),
  ])
}
