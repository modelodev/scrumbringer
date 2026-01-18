//// HTTP handlers for task notes (comments).
////
//// Provides endpoints for listing notes on a task and adding
//// new notes. Requires task access (membership in task's project).

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/task_notes_db
import wisp

/// Routes /api/tasks/:id/notes requests (GET list, POST create).
pub fn handle_task_notes(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx, task_id)
    http.Post -> handle_create(req, ctx, task_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(task_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(task_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case require_task_access(db, task_id, user.id) {
            Error(resp) -> resp

            Ok(Nil) ->
              case task_notes_db.list_notes_for_task(db, task_id) {
                Ok(notes) ->
                  api.ok(
                    json.object([#("notes", json.array(notes, of: note_json))]),
                  )

                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }
          }
        }
      }
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

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
                    use content <- decode.field("content", decode.string)
                    decode.success(content)
                  }

                  case decode.run(data, decoder) {
                    Error(_) ->
                      api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                    Ok(content) ->
                      case
                        task_notes_db.create_note(db, task_id, user.id, content)
                      {
                        Ok(note) ->
                          api.ok(json.object([#("note", note_json(note))]))

                        Error(task_notes_db.DbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")

                        Error(task_notes_db.UnexpectedEmptyResult) ->
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

fn note_json(note: task_notes_db.TaskNote) -> json.Json {
  let task_notes_db.TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
  ) = note

  json.object([
    #("id", json.int(id)),
    #("task_id", json.int(task_id)),
    #("user_id", json.int(user_id)),
    #("content", json.string(content)),
    #("created_at", json.string(created_at)),
  ])
}
