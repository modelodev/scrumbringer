//// HTTP handler for card view tracking.

import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/resource_views
import scrumbringer_server/use_case/cards_db
import scrumbringer_server/use_case/user_card_views_db
import wisp

/// Routes PUT /api/v1/views/cards/:id requests.
pub fn handle_card_view(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> wisp.Response {
  resource_views.handle_put(
    req,
    ctx,
    card_id,
    fetch_card_project_id,
    user_card_views_db.touch_card_view,
  )
}

fn fetch_card_project_id(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(Int, wisp.Response) {
  case cards_db.get_card(db, card_id, user_id) {
    Ok(card) -> Ok(card.project_id)
    Error(error) -> Error(card_error_response(error))
  }
}

fn card_error_response(error: cards_db.CardError) -> wisp.Response {
  case error {
    cards_db.CardNotFound -> not_found_response()
    cards_db.InvalidParentCard
    | cards_db.InvalidParentExecutionPhase(_)
    | cards_db.ParentCardClosed
    | cards_db.ParentDoesNotAcceptCards
    | cards_db.InvalidColor(_)
    | cards_db.InvalidMovePoolToParentCard
    | cards_db.CardHasClaimedDescendant(_)
    | cards_db.CannotActivateClosedCard
    | cards_db.CardAlreadyClosed
    | cards_db.CannotMoveClosedCard
    | cards_db.CannotMoveIntoClosedCard
    | cards_db.DestinationDoesNotAcceptCards
    | cards_db.DestinationNotFound
    | cards_db.MoveWouldCreateCycle -> unexpected_error_response()
    cards_db.DbError(_) -> database_error_response()
  }
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}

fn unexpected_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Unexpected error")
}
