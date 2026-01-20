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

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      // Check user is member of project
      case auth.is_project_member(db, user.id, project_id) {
        False -> api.error(403, "FORBIDDEN", "Not a member of this project")
        True -> {
          case cards_db.list_cards(db, project_id) {
            Ok(cards) -> api.ok(json.object([#("cards", cards_to_json(cards))]))
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn require_project_admin(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case auth.is_project_admin(db, user_id, project_id) {
    True -> Ok(Nil)
    False -> Error(api.error(403, "FORBIDDEN", "Project admin role required"))
  }
}

/// Valid card colors.
const valid_colors = ["gray", "red", "orange", "yellow", "green", "blue", "purple", "pink"]

fn validate_color(color: String) -> Result(Option(String), wisp.Response) {
  case color {
    "" -> Ok(None)
    c -> {
      case list.contains(valid_colors, c) {
        True -> Ok(Some(c))
        False -> Error(api.error(422, "VALIDATION_ERROR", "Invalid color value"))
      }
    }
  }
}

fn decode_card_payload_data(
  data: dynamic.Dynamic,
) -> Result(#(String, Option(String), Option(String)), wisp.Response) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use color <- decode.optional_field("color", "", decode.string)
    decode.success(#(title, description, color))
  }

  case decode.run(data, decoder) {
    Ok(#(title, description, color)) -> {
      case validate_color(color) {
        Error(resp) -> Error(resp)
        Ok(validated_color) ->
          Ok(
            #(
              title,
              case description {
                "" -> None
                s -> Some(s)
              },
              validated_color,
            ),
          )
      }
    }
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid JSON body"))
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          let auth.Ctx(db: db, ..) = ctx

          case require_project_admin(db, user.id, project_id) {
            Error(resp) -> resp
            Ok(Nil) -> {
              use data <- wisp.require_json(req)

              case decode_card_payload_data(data) {
                Error(resp) -> resp
                Ok(#(title, description, color)) -> {
                  case
                    cards_db.create_card(
                      db,
                      project_id,
                      title,
                      description,
                      color,
                      user.id,
                    )
                  {
                    Ok(card) ->
                      api.ok(json.object([#("card", card_to_json(card))]))
                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }
                }
              }
            }
          }
        }
      }
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

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case cards_db.get_card(db, card_id) {
        Error(cards_db.CardNotFound) ->
          api.error(404, "NOT_FOUND", "Card not found")
        Error(cards_db.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Error(_) -> api.error(500, "INTERNAL", "Unexpected error")

        Ok(card) -> {
          // Check user is member of the card's project
          case auth.is_project_member(db, user.id, card.project_id) {
            False -> api.error(403, "FORBIDDEN", "Not a member of this project")
            True -> api.ok(json.object([#("card", card_to_json(card))]))
          }
        }
      }
    }
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          let auth.Ctx(db: db, ..) = ctx

          // First get the card to find its project_id
          case cards_db.get_card(db, card_id) {
            Error(cards_db.CardNotFound) ->
              api.error(404, "NOT_FOUND", "Card not found")
            Error(_) -> api.error(500, "INTERNAL", "Database error")

            Ok(card) -> {
              case require_project_admin(db, user.id, card.project_id) {
                Error(resp) -> resp
                Ok(Nil) -> {
                  use data <- wisp.require_json(req)

                  case decode_card_payload_data(data) {
                    Error(resp) -> resp
                    Ok(#(title, description, color)) -> {
                      case
                        cards_db.update_card(db, card_id, title, description, color)
                      {
                        Ok(updated) ->
                          api.ok(
                            json.object([#("card", card_to_json(updated))]),
                          )
                        Error(cards_db.CardNotFound) ->
                          api.error(404, "NOT_FOUND", "Card not found")
                        Error(_) -> api.error(500, "INTERNAL", "Database error")
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          let auth.Ctx(db: db, ..) = ctx

          // First get the card to find its project_id
          case cards_db.get_card(db, card_id) {
            Error(cards_db.CardNotFound) ->
              api.error(404, "NOT_FOUND", "Card not found")
            Error(_) -> api.error(500, "INTERNAL", "Database error")

            Ok(card) -> {
              case require_project_admin(db, user.id, card.project_id) {
                Error(resp) -> resp
                Ok(Nil) ->
                  case cards_db.delete_card(db, card_id) {
                    Ok(Nil) -> wisp.no_content()
                    Error(cards_db.CardHasTasks(count)) ->
                      api.error(
                        409,
                        "CONFLICT_HAS_TASKS",
                        "Cannot delete card with "
                          <> int.to_string(count)
                          <> " tasks",
                      )
                    Error(cards_db.CardNotFound) ->
                      api.error(404, "NOT_FOUND", "Card not found")
                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }
              }
            }
          }
        }
      }
  }
}

// =============================================================================
// JSON Serialization
// =============================================================================

fn card_to_json(card: cards_db.Card) -> json.Json {
  json.object([
    #("id", json.int(card.id)),
    #("project_id", json.int(card.project_id)),
    #("title", json.string(card.title)),
    #("description", json.string(card.description)),
    #("color", json.string(card.color)),
    #("state", json.string(cards_db.state_to_string(card.state))),
    #("task_count", json.int(card.task_count)),
    #("completed_count", json.int(card.completed_count)),
    #("created_by", json.int(card.created_by)),
    #("created_at", json.string(card.created_at)),
  ])
}

fn cards_to_json(cards: List(cards_db.Card)) -> json.Json {
  json.array(cards, of: card_to_json)
}
