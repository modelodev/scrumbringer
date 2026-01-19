//// Cards API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides card (ficha) management API operations including listing, creating,
//// updating, and deleting cards within projects.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/cards
////
//// cards.list_cards(project_id, CardsFetched)
//// cards.create_card(project_id, "Title", "Desc", CardCreated)
//// ```

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}

import domain/card.{type Card, type CardState, Card, Cerrada, EnCurso, Pendiente}

// =============================================================================
// Decoders
// =============================================================================

fn card_state_decoder() -> decode.Decoder(CardState) {
  use state_str <- decode.then(decode.string)
  case state_str {
    "en_curso" -> decode.success(EnCurso)
    "cerrada" -> decode.success(Cerrada)
    _ -> decode.success(Pendiente)
  }
}

fn card_decoder() -> decode.Decoder(Card) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use state <- decode.field("state", card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Card(
    id: id,
    project_id: project_id,
    title: title,
    description: description,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
  ))
}

// =============================================================================
// API Functions
// =============================================================================

/// List all cards for a project.
pub fn list_cards(
  project_id: Int,
  to_msg: fn(ApiResult(List(Card))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("cards", decode.list(card_decoder()), decode.success)
  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
    option.None,
    decoder,
    to_msg,
  )
}

/// Create a new card in a project.
pub fn create_card(
  project_id: Int,
  title: String,
  description: String,
  to_msg: fn(ApiResult(Card)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("title", json.string(title)),
      #("description", json.string(description)),
    ])
  let decoder = decode.field("card", card_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Get a single card by ID.
pub fn get_card(card_id: Int, to_msg: fn(ApiResult(Card)) -> msg) -> Effect(msg) {
  let decoder = decode.field("card", card_decoder(), decode.success)
  core.request(
    "GET",
    "/api/v1/cards/" <> int.to_string(card_id),
    option.None,
    decoder,
    to_msg,
  )
}

/// Update a card's title and description.
pub fn update_card(
  card_id: Int,
  title: String,
  description: String,
  to_msg: fn(ApiResult(Card)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("title", json.string(title)),
      #("description", json.string(description)),
    ])
  let decoder = decode.field("card", card_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/cards/" <> int.to_string(card_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Delete a card (only if it has no tasks).
pub fn delete_card(
  card_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/cards/" <> int.to_string(card_id),
    option.None,
    to_msg,
  )
}
