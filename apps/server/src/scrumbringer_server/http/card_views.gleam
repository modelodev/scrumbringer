//// HTTP handler for card view tracking.

import gleam/http
import gleam/int
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/authorization
import scrumbringer_server/services/cards_db
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/user_card_views_db
import wisp

/// Routes PUT /api/v1/views/cards/:id requests.
pub fn handle_card_view(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> wisp.Response {
  case req.method {
    http.Put -> handle_put(req, ctx, card_id)
    _ -> wisp.method_not_allowed([http.Put])
  }
}

fn handle_put(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> mark_view_for_user(req, ctx, user, card_id)
  }
}

fn mark_view_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> mark_view_with_csrf(ctx, user, card_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn mark_view_with_csrf(
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: String,
) -> wisp.Response {
  case parse_card_id(card_id) {
    Error(resp) -> resp
    Ok(card_id) -> mark_view(ctx, user, card_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn mark_view(ctx: auth.Ctx, user: StoredUser, card_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case cards_db.get_card(db, card_id, user.id) {
    Error(cards_db.CardNotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(cards_db.DbError(_)) -> api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Database error")
    Ok(card) ->
      case authorization.is_project_member(db, user.id, card.project_id) {
        False -> api.error(404, "NOT_FOUND", "Not found")
        True -> mark_view_in_db(db, user.id, card_id)
      }
  }
}

fn mark_view_in_db(
  db: pog.Connection,
  user_id: Int,
  card_id: Int,
) -> wisp.Response {
  case user_card_views_db.touch_card_view(db, user_id, card_id) {
    Ok(_) -> api.no_content()
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn parse_card_id(card_id: String) -> Result(Int, wisp.Response) {
  case int.parse(card_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}
