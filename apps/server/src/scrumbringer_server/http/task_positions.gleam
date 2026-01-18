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
import scrumbringer_server/services/task_positions_db
import wisp

pub fn handle_me_task_positions(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let query = wisp.get_query(req)

      case parse_project_id_filter(query) {
        Error(resp) -> resp

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case project_id {
            0 ->
              case
                task_positions_db.list_positions_for_user(
                  db,
                  user.id,
                  project_id,
                )
              {
                Ok(positions) ->
                  api.ok(
                    json.object([
                      #("positions", json.array(positions, of: position_json)),
                    ]),
                  )

                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }

            _ ->
              case require_project_member(db, project_id, user.id) {
                Error(resp) -> resp

                Ok(Nil) ->
                  case
                    task_positions_db.list_positions_for_user(
                      db,
                      user.id,
                      project_id,
                    )
                  {
                    Ok(positions) ->
                      api.ok(
                        json.object([
                          #(
                            "positions",
                            json.array(positions, of: position_json),
                          ),
                        ]),
                      )

                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }
              }
          }
        }
      }
    }
  }
}

pub fn handle_me_task_position(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case require_task_access(db, task_id, user.id) {
                Error(resp) -> resp

                Ok(Nil) -> {
                  use data <- wisp.require_json(req)

                  let decoder = {
                    use x <- decode.field("x", decode.int)
                    use y <- decode.field("y", decode.int)
                    decode.success(#(x, y))
                  }

                  case decode.run(data, decoder) {
                    Error(_) ->
                      api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                    Ok(#(x, y)) ->
                      case
                        task_positions_db.upsert_position(
                          db,
                          task_id,
                          user.id,
                          x,
                          y,
                        )
                      {
                        Ok(position) ->
                          api.ok(
                            json.object([#("position", position_json(position))]),
                          )

                        Error(task_positions_db.DbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")

                        Error(task_positions_db.UnexpectedEmptyResult) ->
                          api.error(500, "INTERNAL", "Database error")
                      }
                  }
                }
              }
            }
          }
      }
  }
}

fn parse_project_id_filter(
  query: List(#(String, String)),
) -> Result(Int, wisp.Response) {
  case single_query_value(query, "project_id") {
    Ok(None) -> Ok(0)

    Ok(Some(value)) ->
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
