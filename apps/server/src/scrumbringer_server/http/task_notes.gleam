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
//// - Task repository (see `repository/tasks/queries.gleam`)
//// - Note repository (see `use_case/task_notes_db.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for user identity
//// - Uses `use_case/task_notes_db.gleam` for repository

import domain/note/entity.{type Note}
import domain/task.{type Task}
import domain/user/id as user_id
import gleam/http
import gleam/option
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/notes/mutations as note_mutations
import scrumbringer_server/http/service_error_response
import scrumbringer_server/http/task_notes/presenters as note_presenters
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/authorization
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/task_notes_db
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

/// Routes /api/tasks/:id/notes/:note_id requests (DELETE).
pub fn handle_task_note(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  note_id: String,
) -> wisp.Response {
  case req.method {
    http.Delete -> handle_delete(req, ctx, task_id, note_id)
    _ -> wisp.method_not_allowed([http.Delete])
  }
}

/// Routes /api/tasks/:id/notes/:note_id/pin requests.
pub fn handle_task_note_pin(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  note_id: String,
) -> wisp.Response {
  case req.method {
    http.Post -> handle_pin(req, ctx, task_id, note_id, True)
    http.Delete -> handle_pin(req, ctx, task_id, note_id, False)
    _ -> wisp.method_not_allowed([http.Post, http.Delete])
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

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  note_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Delete)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> delete_note_for_user(req, ctx, user, task_id, note_id)
  }
}

fn handle_pin(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  note_id: String,
  pinned: Bool,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) ->
      case auth.require_current_user_response(req, ctx) {
        Error(resp) -> resp
        Ok(user) ->
          set_note_pinned_with_csrf(ctx, user, task_id, note_id, pinned)
      }
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
    create_note(ctx, user, task_id, payload.content, payload.url)
  })
}

fn create_note(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  content: String,
  url: option.Option(String),
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case create_note_payload(db, user, task_id, content, url) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn create_note_payload(
  db: pog.Connection,
  user: StoredUser,
  task_id: Int,
  content: String,
  url: option.Option(String),
) -> Result(wisp.Response, wisp.Response) {
  use _ <- result.try(require_task_access(db, task_id, user.id))

  case task_notes_db.create_note(db, task_id, user.id, content, url) {
    Ok(note) -> Ok(api.ok(note_presenters.note_response(note)))
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn delete_note_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
  note_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> delete_note_with_csrf(ctx, user, task_id, note_id)
  }
}

fn delete_note_with_csrf(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
  note_id: String,
) -> wisp.Response {
  case api.parse_id(task_id), api.parse_id(note_id) {
    Error(resp), _ -> resp
    _, Error(resp) -> resp
    Ok(task_id), Ok(note_id) -> delete_note(ctx, user, task_id, note_id)
  }
}

fn set_note_pinned_with_csrf(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
  note_id: String,
  pinned: Bool,
) -> wisp.Response {
  case api.parse_id(task_id), api.parse_id(note_id) {
    Error(resp), _ -> resp
    _, Error(resp) -> resp
    Ok(task_id), Ok(note_id) ->
      set_note_pinned(ctx, user, task_id, note_id, pinned)
  }
}

fn delete_note(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  note_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case authorize_note_delete(db, user, task_id, note_id) {
    Ok(Nil) -> delete_note_in_db(db, task_id, note_id)
    Error(resp) -> resp
  }
}

fn set_note_pinned(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  note_id: Int,
  pinned: Bool,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case authorize_note_delete(db, user, task_id, note_id) {
    Ok(Nil) -> set_note_pinned_in_db(db, task_id, note_id, pinned)
    Error(resp) -> resp
  }
}

fn authorize_note_delete(
  db: pog.Connection,
  user: StoredUser,
  task_id: Int,
  note_id: Int,
) -> Result(Nil, wisp.Response) {
  use task <- result.try(require_task_access(db, task_id, user.id))
  use note <- result.try(get_note(db, task_id, note_id))

  case can_delete_note(db, user, task.project_id, note) {
    True -> Ok(Nil)
    False -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn get_note(
  db: pog.Connection,
  task_id: Int,
  note_id: Int,
) -> Result(Note, wisp.Response) {
  case task_notes_db.get_note(db, task_id, note_id) {
    Ok(note) -> Ok(note)
    Error(error) -> Error(service_error_response.to_response(error))
  }
}

fn delete_note_in_db(
  db: pog.Connection,
  task_id: Int,
  note_id: Int,
) -> wisp.Response {
  case task_notes_db.delete_note(db, task_id, note_id) {
    Ok(Nil) -> api.no_content()
    Error(error) -> service_error_response.to_response(error)
  }
}

fn set_note_pinned_in_db(
  db: pog.Connection,
  task_id: Int,
  note_id: Int,
  pinned: Bool,
) -> wisp.Response {
  case task_notes_db.set_note_pinned(db, task_id, note_id, pinned) {
    Ok(note) -> api.ok(note_presenters.note_response(note))
    Error(error) -> service_error_response.to_response(error)
  }
}

fn can_delete_note(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
  note: Note,
) -> Bool {
  let author_id = user_id.to_int(note.user_id)

  case
    authorization.require_project_manager_with_org_bypass(db, user, project_id)
  {
    Ok(_) -> True
    Error(_) -> user.id == author_id
  }
}

fn require_task_access(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Task, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(task)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}
