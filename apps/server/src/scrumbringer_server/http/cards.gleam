//// HTTP handlers for cards (fichas).
////
//// ## Mission
////
//// Handles HTTP requests for card CRUD operations.
////
//// ## Responsibilities
////
//// - HTTP method validation
//// - Authentication and authorization checks
//// - Request body parsing
//// - CSRF validation
//// - Response JSON construction
////
//// ## Endpoints
////
//// - GET  /api/v1/projects/:project_id/cards
//// - POST /api/v1/projects/:project_id/cards
//// - GET  /api/v1/cards/:card_id
//// - PATCH /api/v1/cards/:card_id
//// - DELETE /api/v1/cards/:card_id
//// - POST /api/v1/cards/:card_id/activate
//// - POST /api/v1/cards/:card_id/close
//// - POST /api/v1/cards/:card_id/move
//// - GET  /api/v1/cards/:card_id/tasks

import api/cards/contracts as card_contracts
import domain/card.{type Card}
import gleam/http
import gleam/int
import gleam/json
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/cards/payloads as card_payloads
import scrumbringer_server/http/cards/presenters as card_presenters
import scrumbringer_server/http/csrf
import scrumbringer_server/http/query
import scrumbringer_server/use_case/authorization
import scrumbringer_server/use_case/cards_db
import scrumbringer_server/use_case/metrics_db
import wisp

fn card_not_found_response(include_metrics: Bool) -> wisp.Response {
  case include_metrics {
    True -> api.error(404, "not_found", "Card not found")
    False -> api.error(404, "NOT_FOUND", "Card not found")
  }
}

fn forbidden_project_member_response(include_metrics: Bool) -> wisp.Response {
  case include_metrics {
    True -> api.error(403, "forbidden", "Not a member of this project")
    False -> api.error(403, "FORBIDDEN", "Not a member of this project")
  }
}

fn card_error_response(error: cards_db.CardError) -> wisp.Response {
  case error {
    cards_db.CardNotFound -> api.error(404, "NOT_FOUND", "Card not found")
    cards_db.InvalidParentCard ->
      api.error(422, "VALIDATION_ERROR", "Invalid parent_card_id")
    cards_db.InvalidMovePoolToParentCard ->
      api.error(
        422,
        "INVALID_MOVE_POOL_TO_PARENT_CARD",
        "Cannot move pool content into a parent card",
      )
    cards_db.InvalidParentExecutionPhase(_) ->
      api.error(500, "INTERNAL", "Invalid parent card state in database")
    cards_db.InvalidColor(_) -> api.error(500, "INTERNAL", "Invalid card color")
    cards_db.CardHasClaimedDescendant(_) ->
      api.error(
        409,
        "CARD_HAS_CLAIMED_DESCENDANT",
        "Cannot close card with claimed descendant tasks",
      )
    cards_db.DbError(_) -> api.error(500, "INTERNAL", "Database error")
    cards_db.CardHasTasks(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

// =============================================================================
// Public Handlers
// =============================================================================

/// Handle GET|POST /api/v1/projects/:project_id/cards
pub fn handle_project_cards(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx, project_id)
    http.Post -> handle_create(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> list_cards_for_user(ctx, project_id, user.id)
  }
}

fn list_cards_for_user(
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case authorization.is_project_member(db, user_id, project_id) {
    False -> api.error(403, "FORBIDDEN", "Not a member of this project")
    True -> list_cards_in_project(db, project_id, user_id)
  }
}

fn list_cards_in_project(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case cards_db.list_cards(db, project_id, user_id) {
    Ok(cards) -> api.ok(card_presenters.cards_response(cards))
    Error(error) -> card_error_response(error)
  }
}

fn require_project_admin(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case authorization.is_project_manager(db, user_id, project_id) {
    True -> Ok(Nil)
    False -> Error(api.error(403, "FORBIDDEN", "Project admin role required"))
  }
}

fn decode_card_payload_data(
  data,
) -> Result(card_payloads.CardPayload, wisp.Response) {
  case card_payloads.decode_card(data) {
    Ok(payload) -> Ok(payload)
    Error(card_payloads.InvalidJson) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid JSON body"))
    Error(card_payloads.InvalidColor) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid color value"))
  }
}

fn with_card_payload(
  req: wisp.Request,
  handle_payload: fn(card_payloads.CardPayload) -> wisp.Response,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_card_payload_data(data) {
    Error(resp) -> resp
    Ok(payload) -> handle_payload(payload)
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> create_card_with_csrf(req, ctx, project_id, user.id)
  }
}

fn create_card_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> create_card_with_auth(req, ctx, project_id, user_id)
  }
}

fn create_card_with_auth(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_project_admin(db, user_id, project_id) {
    Error(resp) -> resp
    Ok(Nil) -> create_card_with_payload(req, ctx, project_id, user_id)
  }
}

fn create_card_with_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  with_card_payload(req, fn(payload) {
    create_card_in_project(ctx, project_id, payload, user_id)
  })
}

fn create_card_in_project(
  ctx: auth.Ctx,
  project_id: Int,
  payload: card_payloads.CardPayload,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case
    cards_db.create_card(
      db,
      project_id,
      payload.parent_card_id,
      payload.title,
      payload.description,
      payload.color,
      user_id,
    )
  {
    Ok(card) -> api.ok(card_presenters.card_response(card))
    Error(error) -> card_error_response(error)
  }
}

/// Handle GET|PATCH|DELETE /api/v1/cards/:card_id
pub fn handle_card(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_get(req, ctx, card_id)
    http.Patch -> handle_update(req, ctx, card_id)
    http.Delete -> handle_delete(req, ctx, card_id)
    _ -> wisp.method_not_allowed([http.Get, http.Patch, http.Delete])
  }
}

pub fn handle_activate(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case req.method {
    http.Post -> handle_card_action(req, ctx, card_id, activate_card_in_db)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_close(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case req.method {
    http.Post -> handle_close_request(req, ctx, card_id)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_move(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case req.method {
    http.Post -> handle_move_request(req, ctx, card_id)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

fn handle_card_action(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  action: fn(auth.Ctx, Int, Int) -> wisp.Response,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) ->
      case csrf.require_csrf(req) {
        Error(resp) -> resp
        Ok(Nil) -> action_card_with_auth(ctx, card_id, user.id, action)
      }
  }
}

fn action_card_with_auth(
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
  action: fn(auth.Ctx, Int, Int) -> wisp.Response,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx
  case cards_db.get_card(db, card_id, user_id) {
    Error(error) -> card_error_response(error)
    Ok(card) ->
      case require_project_admin(db, user_id, card.project_id) {
        Error(resp) -> resp
        Ok(Nil) -> action(ctx, card_id, user_id)
      }
  }
}

fn activate_card_in_db(
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx
  case cards_db.activate_card(db, card_id, user_id) {
    Ok(pool_impact) -> card_action_response(card_id, pool_impact)
    Error(error) -> card_error_response(error)
  }
}

fn handle_close_request(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  case card_contracts.decode_card_close(data) {
    Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid close request")
    Ok(_) -> handle_card_action(req, ctx, card_id, close_card_in_db)
  }
}

fn close_card_in_db(ctx: auth.Ctx, card_id: Int, user_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx
  case cards_db.close_card(db, card_id, user_id) {
    Ok(pool_impact) -> card_action_response(card_id, pool_impact)
    Error(error) -> card_error_response(error)
  }
}

fn handle_move_request(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  case card_contracts.decode_card_move(data) {
    Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid move request")
    Ok(card_contracts.CardMoveRequest(parent_card_id: parent_card_id)) ->
      handle_card_action(req, ctx, card_id, fn(ctx, card_id, _user_id) {
        move_card_in_db(ctx, card_id, parent_card_id)
      })
  }
}

fn move_card_in_db(ctx: auth.Ctx, card_id: Int, parent_card_id) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx
  case cards_db.move_card(db, card_id, parent_card_id) {
    Ok(pool_impact) -> card_action_response(card_id, pool_impact)
    Error(error) -> card_error_response(error)
  }
}

fn card_action_response(card_id: Int, pool_impact: Int) -> wisp.Response {
  card_contracts.CardActionResponse(card_id: card_id, pool_impact: pool_impact)
  |> card_contracts.action_response_to_json
  |> json.to_string
  |> wisp.json_response(200)
}

fn handle_get(req: wisp.Request, ctx: auth.Ctx, card_id: Int) -> wisp.Response {
  let include_metrics = wants_metrics(req)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> get_card_for_user(req, ctx, card_id, user.id, include_metrics)
  }
}

fn get_card_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
  include_metrics: Bool,
) -> wisp.Response {
  let _ = req
  let auth.Ctx(db: db, ..) = ctx

  case cards_db.get_card(db, card_id, user_id) {
    Error(cards_db.CardNotFound) -> card_not_found_response(include_metrics)
    Error(error) -> card_error_response(error)
    Ok(card) -> respond_with_card_if_member(db, user_id, card, include_metrics)
  }
}

fn respond_with_card_if_member(
  db: pog.Connection,
  user_id: Int,
  card: Card,
  include_metrics: Bool,
) -> wisp.Response {
  case authorization.is_project_member(db, user_id, card.project_id) {
    False -> forbidden_project_member_response(include_metrics)
    True -> {
      case include_metrics {
        True ->
          case metrics_db.get_card_metrics(db, card.id) {
            Ok(metrics) ->
              api.ok(card_presenters.card_metrics_response(card.id, metrics))
            Error(metrics_db.NotFound) ->
              api.error(404, "not_found", "Card not found")
            Error(metrics_db.MetricsUnavailable) ->
              api.error(409, "metrics_unavailable", "Metrics unavailable")
            Error(metrics_db.DbError(_)) ->
              api.error(500, "internal", "Database error")
          }
        False -> api.ok(card_presenters.card_response(card))
      }
    }
  }
}

fn wants_metrics(req: wisp.Request) -> Bool {
  query.has_value(wisp.get_query(req), "include", "metrics")
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> update_card_with_csrf(req, ctx, card_id, user.id)
  }
}

fn update_card_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> update_card_with_auth(req, ctx, card_id, user_id)
  }
}

fn update_card_with_auth(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case cards_db.get_card(db, card_id, user_id) {
    Error(error) -> card_error_response(error)
    Ok(card) -> update_card_in_project(req, ctx, card, user_id)
  }
}

fn update_card_in_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  card: Card,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_project_admin(db, user_id, card.project_id) {
    Error(resp) -> resp
    Ok(Nil) -> update_card_with_payload(req, ctx, card.id, user_id)
  }
}

fn update_card_with_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  with_card_payload(req, fn(payload) {
    update_card_in_db(ctx, card_id, payload, user_id)
  })
}

fn update_card_in_db(
  ctx: auth.Ctx,
  card_id: Int,
  payload: card_payloads.CardPayload,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case
    cards_db.update_card(
      db,
      card_id,
      payload.parent_card_id,
      payload.title,
      payload.description,
      payload.color,
      user_id,
    )
  {
    Ok(updated) -> api.ok(card_presenters.card_response(updated))
    Error(error) -> card_error_response(error)
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> delete_card_with_csrf(req, ctx, card_id, user.id)
  }
}

fn delete_card_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> delete_card_with_auth(ctx, card_id, user_id)
  }
}

fn delete_card_with_auth(
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case cards_db.get_card(db, card_id, user_id) {
    Error(error) -> card_error_response(error)
    Ok(card) -> delete_card_in_project(ctx, card, user_id)
  }
}

fn delete_card_in_project(
  ctx: auth.Ctx,
  card: Card,
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_project_admin(db, user_id, card.project_id) {
    Error(resp) -> resp
    Ok(Nil) -> delete_card_in_db(db, card.id)
  }
}

fn delete_card_in_db(db: pog.Connection, card_id: Int) -> wisp.Response {
  case cards_db.delete_card(db, card_id) {
    Ok(Nil) -> wisp.no_content()
    Error(cards_db.CardHasTasks(count)) ->
      api.error(
        409,
        "CONFLICT_HAS_TASKS",
        "Cannot delete card with " <> int.to_string(count) <> " tasks",
      )
    Error(error) -> card_error_response(error)
  }
}
