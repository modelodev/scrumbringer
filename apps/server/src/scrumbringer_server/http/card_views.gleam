//// HTTP handler for card view tracking.

import gleam/http
import gleam/result
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

  case mark_view_payload(req, ctx, card_id) {
    Ok(Nil) -> api.no_content()
    Error(resp) -> resp
  }
}

fn mark_view_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> Result(Nil, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use card_id <- result.try(api.parse_id(card_id))

  mark_view(ctx, user, card_id)
}

fn mark_view(
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: Int,
) -> Result(Nil, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use card <- result.try(fetch_card(db, card_id, user.id))
  use Nil <- result.try(require_project_member(db, user.id, card.project_id))

  mark_view_in_db(db, user.id, card_id)
}

fn mark_view_in_db(
  db: pog.Connection,
  user_id: Int,
  card_id: Int,
) -> Result(Nil, wisp.Response) {
  case user_card_views_db.touch_card_view(db, user_id, card_id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(database_error_response())
  }
}

fn fetch_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(cards_db.Card, wisp.Response) {
  case cards_db.get_card(db, card_id, user_id) {
    Ok(card) -> Ok(card)
    Error(error) -> Error(card_error_response(error))
  }
}

fn require_project_member(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case authorization.is_project_member(db, user_id, project_id) {
    True -> Ok(Nil)
    False -> Error(not_found_response())
  }
}

fn card_error_response(error: cards_db.CardError) -> wisp.Response {
  case error {
    cards_db.CardNotFound -> not_found_response()
    cards_db.CardHasTasks(_) -> database_error_response()
    cards_db.InvalidMilestone -> database_error_response()
    cards_db.InvalidMilestoneState(_) -> database_error_response()
    cards_db.InvalidColor(_) -> database_error_response()
    cards_db.InvalidMovePoolToMilestone -> database_error_response()
    cards_db.DbError(_) -> database_error_response()
  }
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
