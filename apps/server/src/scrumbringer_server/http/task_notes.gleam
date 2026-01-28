//// HTTP handlers for task notes (comments).
////
//// ## Mission
////
//// Provide endpoints for listing and creating notes on tasks.
////
//// ## Responsibilities
////
//// - Parse route params and JSON payloads
//// - Enforce CSRF for mutations
//// - Validate task access
////
//// ## Non-responsibilities
////
//// - Task persistence (see `persistence/tasks/queries.gleam`)
//// - Note persistence (see `services/task_notes_db.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for user identity
//// - Uses `services/task_notes_db.gleam` for persistence

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/task_notes_db
import wisp

/// Routes /api/tasks/:id/notes requests (GET list, POST create).
///
/// Example:
///   handle_task_notes(req, ctx, "123")
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
    Ok(user) -> list_notes_for_user(ctx, user, task_id)
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
    Ok(user) -> create_note_for_user(req, ctx, user, task_id)
  }
}

fn list_notes_for_user(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp
    Ok(task_id) -> list_notes(ctx, user.id, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn list_notes(ctx: auth.Ctx, user_id: Int, task_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_task_access(db, task_id, user_id) {
    Error(resp) -> resp

    Ok(Nil) ->
      case task_notes_db.list_notes_for_task(db, task_id) {
        Ok(notes) ->
          api.ok(json.object([#("notes", json.array(notes, of: note_json))]))

        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
  }
}

fn create_note_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> create_note_with_csrf(req, ctx, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn create_note_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp

    Ok(task_id) -> {
      use data <- wisp.require_json(req)

      case decode_note_payload(data) {
        Error(resp) -> resp
        Ok(content) -> create_note(ctx, user, task_id, content)
      }
    }
  }
}

// Justification: nested case improves clarity for branching logic.
fn create_note(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  content: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_task_access(db, task_id, user.id) {
    Error(resp) -> resp

    Ok(Nil) ->
      case task_notes_db.create_note(db, task_id, user.id, content) {
        Ok(note) -> api.ok(json.object([#("note", note_json(note))]))
        Error(task_notes_db.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Error(task_notes_db.UnexpectedEmptyResult) ->
          api.error(500, "INTERNAL", "Database error")
      }
  }
}

fn decode_note_payload(data: dynamic.Dynamic) -> Result(String, wisp.Response) {
  let decoder = {
    use content <- decode.field("content", decode.string)
    decode.success(content)
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(content) -> Ok(content)
  }
}


fn parse_task_id(task_id: String) -> Result(Int, wisp.Response) {
  case int.parse(task_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
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
