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
//// - GET  /api/v1/cards/:card_id/tasks

import gleam/dynamic
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
import scrumbringer_server/services/authorization
import scrumbringer_server/services/cards_db
import wisp

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
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
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
    Ok(cards) -> api.ok(json.object([#("cards", cards_to_json(cards))]))
    Error(_) -> api.error(500, "INTERNAL", "Database error")
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

/// Valid card colors.
const valid_colors = [
  "gray",
  "red",
  "orange",
  "yellow",
  "green",
  "blue",
  "purple",
  "pink",
]

fn validate_color(color: String) -> Result(Option(String), wisp.Response) {
  case color {
    "" -> Ok(None)
    c -> validate_named_color(c)
  }
}

fn validate_named_color(color: String) -> Result(Option(String), wisp.Response) {
  case list.contains(valid_colors, color) {
    True -> Ok(Some(color))
    False -> Error(api.error(422, "VALIDATION_ERROR", "Invalid color value"))
  }
}

fn decode_card_payload_data(
  data: dynamic.Dynamic,
) -> Result(
  #(String, Option(String), Option(String), Option(Int)),
  wisp.Response,
) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use color <- decode.optional_field("color", "", decode.string)
    use milestone_id <- decode.optional_field(
      "milestone_id",
      None,
      decode.optional(decode.int),
    )
    decode.success(#(title, description, color, milestone_id))
  }

  case decode.run(data, decoder) {
    Ok(#(title, description, color, milestone_id)) ->
      normalize_card_payload(title, description, color, milestone_id)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid JSON body"))
  }
}

fn normalize_card_payload(
  title: String,
  description: String,
  color: String,
  milestone_id: Option(Int),
) -> Result(
  #(String, Option(String), Option(String), Option(Int)),
  wisp.Response,
) {
  case validate_color(color) {
    Error(resp) -> Error(resp)
    Ok(validated_color) ->
      Ok(#(
        title,
        normalize_optional(description),
        validated_color,
        milestone_id,
      ))
  }
}

fn normalize_optional(value: String) -> Option(String) {
  case value {
    "" -> None
    other -> Some(other)
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> create_card_with_csrf(req, ctx, project_id, user.id)
  }
}

fn create_card_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
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
  use data <- wisp.require_json(req)

  case decode_card_payload_data(data) {
    Error(resp) -> resp
    Ok(#(title, description, color, milestone_id)) ->
      create_card_in_project(
        ctx,
        project_id,
        milestone_id,
        title,
        description,
        color,
        user_id,
      )
  }
}

fn create_card_in_project(
  ctx: auth.Ctx,
  project_id: Int,
  milestone_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(String),
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case
    cards_db.create_card(
      db,
      project_id,
      milestone_id,
      title,
      description,
      color,
      user_id,
    )
  {
    Ok(card) -> api.ok(json.object([#("card", card_to_json(card))]))
    Error(cards_db.InvalidMilestone) ->
      api.error(422, "VALIDATION_ERROR", "Invalid milestone_id")
    Error(cards_db.InvalidMovePoolToMilestone) ->
      api.error(
        422,
        "INVALID_MOVE_POOL_TO_MILESTONE",
        "Cannot move pool content into a milestone",
      )
    Error(_) -> api.error(500, "INTERNAL", "Database error")
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

fn handle_get(req: wisp.Request, ctx: auth.Ctx, card_id: Int) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> get_card_for_user(ctx, card_id, user.id)
  }
}

fn get_card_for_user(ctx: auth.Ctx, card_id: Int, user_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case cards_db.get_card(db, card_id, user_id) {
    Error(cards_db.CardNotFound) ->
      api.error(404, "NOT_FOUND", "Card not found")
    Error(cards_db.DbError(_)) -> api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
    Ok(card) -> respond_with_card_if_member(db, user_id, card)
  }
}

fn respond_with_card_if_member(
  db: pog.Connection,
  user_id: Int,
  card: cards_db.Card,
) -> wisp.Response {
  case authorization.is_project_member(db, user_id, card.project_id) {
    False -> api.error(403, "FORBIDDEN", "Not a member of this project")
    True -> api.ok(json.object([#("card", card_to_json(card))]))
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> update_card_with_csrf(req, ctx, card_id, user.id)
  }
}

fn update_card_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
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
    Error(cards_db.CardNotFound) ->
      api.error(404, "NOT_FOUND", "Card not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")
    Ok(card) -> update_card_in_project(req, ctx, card, user_id)
  }
}

fn update_card_in_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  card: cards_db.Card,
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
  use data <- wisp.require_json(req)

  case decode_card_payload_data(data) {
    Error(resp) -> resp
    Ok(#(title, description, color, milestone_id)) ->
      update_card_in_db(
        ctx,
        card_id,
        milestone_id,
        title,
        description,
        color,
        user_id,
      )
  }
}

fn update_card_in_db(
  ctx: auth.Ctx,
  card_id: Int,
  milestone_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(String),
  user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case
    cards_db.update_card(
      db,
      card_id,
      milestone_id,
      title,
      description,
      color,
      user_id,
    )
  {
    Ok(updated) -> api.ok(json.object([#("card", card_to_json(updated))]))
    Error(cards_db.CardNotFound) ->
      api.error(404, "NOT_FOUND", "Card not found")
    Error(cards_db.InvalidMilestone) ->
      api.error(422, "VALIDATION_ERROR", "Invalid milestone_id")
    Error(cards_db.InvalidMovePoolToMilestone) ->
      api.error(
        422,
        "INVALID_MOVE_POOL_TO_MILESTONE",
        "Cannot move pool content into a milestone",
      )
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> delete_card_with_csrf(req, ctx, card_id, user.id)
  }
}

fn delete_card_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
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
    Error(cards_db.CardNotFound) ->
      api.error(404, "NOT_FOUND", "Card not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")
    Ok(card) -> delete_card_in_project(ctx, card, user_id)
  }
}

fn delete_card_in_project(
  ctx: auth.Ctx,
  card: cards_db.Card,
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
    Error(cards_db.CardNotFound) ->
      api.error(404, "NOT_FOUND", "Card not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

// =============================================================================
// JSON Serialization
// =============================================================================

fn card_to_json(card: cards_db.Card) -> json.Json {
  json.object([
    #("id", json.int(card.id)),
    #("project_id", json.int(card.project_id)),
    #("milestone_id", option_int_json(card.milestone_id)),
    #("title", json.string(card.title)),
    #("description", json.string(card.description)),
    #("color", json.string(card.color)),
    #("state", json.string(cards_db.state_to_string(card.state))),
    #("task_count", json.int(card.task_count)),
    #("completed_count", json.int(card.completed_count)),
    #("created_by", json.int(card.created_by)),
    #("created_at", json.string(card.created_at)),
    #("has_new_notes", json.bool(card.has_new_notes)),
  ])
}

fn cards_to_json(cards: List(cards_db.Card)) -> json.Json {
  json.array(cards, of: card_to_json)
}

fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.int(v)
  }
}
