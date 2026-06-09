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

import gleam/http
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/notes/mutations as note_mutations
import scrumbringer_server/http/service_error_response
import scrumbringer_server/http/task_notes/presenters as note_presenters
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

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> list_notes_for_user(ctx, user, task_id)
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> create_note_for_user(req, ctx, user, task_id)
  }
}

fn list_notes_for_user(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case api.parse_id(task_id) {
    Error(resp) -> resp
    Ok(task_id) -> list_notes(ctx, user.id, task_id)
  }
}

fn list_notes(ctx: auth.Ctx, user_id: Int, task_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case list_notes_payload(db, user_id, task_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn list_notes_payload(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(wisp.Response, wisp.Response) {
  use _ <- result.try(require_task_access(db, task_id, user_id))

  case task_notes_db.list_notes_for_task(db, task_id) {
    Ok(notes) -> Ok(api.ok(note_presenters.notes_response(notes)))
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn create_note_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  note_mutations.with_note_payload(req, task_id, fn(task_id, payload) {
    create_note(ctx, user, task_id, payload.content)
  })
}

fn create_note(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  content: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case create_note_payload(db, user, task_id, content) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn create_note_payload(
  db: pog.Connection,
  user: StoredUser,
  task_id: Int,
  content: String,
) -> Result(wisp.Response, wisp.Response) {
  use _ <- result.try(require_task_access(db, task_id, user.id))

  case task_notes_db.create_note(db, task_id, user.id, content) {
    Ok(note) -> Ok(api.ok(note_presenters.note_response(note)))
    Error(error) -> Error(service_error_response.to_database_response(error))
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
