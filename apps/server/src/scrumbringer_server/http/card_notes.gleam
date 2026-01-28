//// HTTP handlers for card notes.
////
//// ## Mission
////
//// Provide endpoints for listing, creating, and deleting notes on cards.
////
//// ## Responsibilities
////
//// - Parse route params and JSON payloads
//// - Enforce CSRF for mutations
//// - Validate card access
//// - Enforce note delete permissions
////
//// ## Non-responsibilities
////
//// - Card persistence (see `services/cards_db.gleam`)
//// - Note persistence (see `services/card_notes_db.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for user identity
//// - Uses `services/card_notes_db.gleam` for persistence

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/authorization
import scrumbringer_server/services/card_notes_db
import scrumbringer_server/services/cards_db
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

/// Routes /api/v1/cards/:id/notes requests (GET list, POST create).
pub fn handle_card_notes(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx, card_id)
    http.Post -> handle_create(req, ctx, card_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Routes /api/v1/cards/:id/notes/:note_id requests (DELETE).
pub fn handle_card_note(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
  note_id: String,
) -> wisp.Response {
  case req.method {
    http.Delete -> handle_delete(req, ctx, card_id, note_id)
    _ -> wisp.method_not_allowed([http.Delete])
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> list_notes_for_user(ctx, user, card_id)
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> create_note_for_user(req, ctx, user, card_id)
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
  note_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Delete)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> delete_note_for_user(req, ctx, user, card_id, note_id)
  }
}

fn list_notes_for_user(
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: String,
) -> wisp.Response {
  case parse_card_id(card_id) {
    Error(resp) -> resp
    Ok(card_id) -> list_notes(ctx, user.id, card_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn list_notes(ctx: auth.Ctx, user_id: Int, card_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_card_access(db, card_id, user_id) {
    Error(resp) -> resp

    Ok(_card) ->
      case card_notes_db.list_notes_for_card(db, card_id) {
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
  card_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> create_note_with_csrf(req, ctx, user, card_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn create_note_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: String,
) -> wisp.Response {
  case parse_card_id(card_id) {
    Error(resp) -> resp

    Ok(card_id) -> {
      use data <- wisp.require_json(req)

      case decode_note_payload(data) {
        Error(resp) -> resp
        Ok(content) -> create_note(ctx, user, card_id, content)
      }
    }
  }
}

// Justification: nested case improves clarity for branching logic.
fn create_note(
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: Int,
  content: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_card_access(db, card_id, user.id) {
    Error(resp) -> resp

    Ok(_card) ->
      case card_notes_db.create_note(db, card_id, user.id, content) {
        Ok(note) -> api.ok(json.object([#("note", note_json(note))]))
        Error(card_notes_db.CreateDbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Error(card_notes_db.CreateUnexpectedEmptyResult) ->
          api.error(500, "INTERNAL", "Database error")
      }
  }
}

fn delete_note_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: String,
  note_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> delete_note_with_csrf(ctx, user, card_id, note_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn delete_note_with_csrf(
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: String,
  note_id: String,
) -> wisp.Response {
  case parse_card_id(card_id), parse_note_id(note_id) {
    Error(resp), _ -> resp
    _, Error(resp) -> resp
    Ok(card_id), Ok(note_id) -> delete_note(ctx, user, card_id, note_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn delete_note(
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: Int,
  note_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_card_access(db, card_id, user.id) {
    Error(resp) -> resp

    Ok(card) ->
      case card_notes_db.get_note(db, card_id, note_id) {
        Error(card_notes_db.GetNoteNotFound) ->
          api.error(404, "NOT_FOUND", "Not found")
        Error(card_notes_db.GetDbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Ok(note) ->
          case can_delete_note(db, user, card.project_id, note) {
            False -> api.error(403, "FORBIDDEN", "Forbidden")
            True -> delete_note_in_db(db, card_id, note_id)
          }
      }
  }
}

fn delete_note_in_db(
  db: pog.Connection,
  card_id: Int,
  note_id: Int,
) -> wisp.Response {
  case card_notes_db.delete_note(db, card_id, note_id) {
    Ok(Nil) -> api.no_content()
    Error(card_notes_db.DeleteNoteNotFound) ->
      api.error(404, "NOT_FOUND", "Not found")
    Error(card_notes_db.DeleteDbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
  }
}

fn can_delete_note(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
  note: card_notes_db.CardNote,
) -> Bool {
  let card_notes_db.CardNote(user_id: author_id, ..) = note

  case
    authorization.require_project_manager_with_org_bypass(db, user, project_id)
  {
    Ok(_) -> True
    Error(_) -> user.id == author_id
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


fn parse_card_id(card_id: String) -> Result(Int, wisp.Response) {
  case int.parse(card_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn parse_note_id(note_id: String) -> Result(Int, wisp.Response) {
  case int.parse(note_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn require_card_access(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(cards_db.Card, wisp.Response) {
  case cards_db.get_card(db, card_id, user_id) {
    Error(cards_db.CardNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(cards_db.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
    Ok(card) ->
      case authorization.is_project_member(db, user_id, card.project_id) {
        False -> Error(api.error(404, "NOT_FOUND", "Not found"))
        True -> Ok(card)
      }
  }
}

fn note_json(note: card_notes_db.CardNote) -> json.Json {
  let card_notes_db.CardNote(
    id: id,
    card_id: card_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
    author_email: author_email,
    author_role: author_role,
  ) = note

  json.object([
    #("id", json.int(id)),
    #("card_id", json.int(card_id)),
    #("user_id", json.int(user_id)),
    #("content", json.string(content)),
    #("created_at", json.string(created_at)),
    // AC20: Author info for tooltip
    #("author_email", json.string(author_email)),
    #("author_role", json.string(author_role)),
  ])
}
