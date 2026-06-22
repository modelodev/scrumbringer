//// Cards API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides card management API operations including listing, creating,
//// updating, and deleting cards within projects.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/cards
////
//// cards.list_cards(project_id, CardsFetched)
//// cards.create_card(project_id, "Title", "Desc", CardCreated)
//// cards.list_card_tasks(card_id, CardTasksFetched)
//// ```

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option

import lustre/effect.{type Effect}

import api/cards/contracts
import domain/api_error.{type ApiResult}
import scrumbringer_client/api/core

import domain/card.{type Card, type CardColor}
import domain/card/card_codec
import domain/note/entity.{type Note}
import domain/note/note_codec
import domain/task.{type Task}
import domain/task/task_codec

// =============================================================================
// API Functions
// =============================================================================

/// List all cards for a project.
pub fn list_cards(
  project_id: Int,
  to_msg: fn(ApiResult(List(Card))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "cards",
      decode.list(card_codec.card_decoder()),
      decode.success,
    )
  core.request(
    core.Get,
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
  color: option.Option(CardColor),
  parent_card_id: option.Option(Int),
  to_msg: fn(ApiResult(Card)) -> msg,
) -> Effect(msg) {
  let base_fields = [
    #("title", json.string(title)),
    #("description", json.string(description)),
  ]
  let fields = case color {
    option.Some(c) ->
      list.append(base_fields, [
        #("color", json.string(card.color_to_string(c))),
      ])
    option.None -> base_fields
  }
  let fields = case parent_card_id {
    option.Some(id) -> list.append(fields, [#("parent_card_id", json.int(id))])
    option.None -> fields
  }
  let body = json.object(fields)
  let decoder = decode.field("card", card_codec.card_decoder(), decode.success)
  core.request(
    core.Post,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Get a single card by ID.
pub fn get_card(card_id: Int, to_msg: fn(ApiResult(Card)) -> msg) -> Effect(msg) {
  let decoder = decode.field("card", card_codec.card_decoder(), decode.success)
  core.request(
    core.Get,
    "/api/v1/cards/" <> int.to_string(card_id),
    option.None,
    decoder,
    to_msg,
  )
}

/// Mark a card as viewed for the current user.
pub fn mark_card_view(
  card_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Put,
    "/api/v1/views/cards/" <> int.to_string(card_id),
    option.None,
    to_msg,
  )
}

/// Update a card's title, description, and color.
pub fn update_card(
  card_id: Int,
  title: String,
  description: String,
  color: option.Option(CardColor),
  parent_card_id: option.Option(Int),
  to_msg: fn(ApiResult(Card)) -> msg,
) -> Effect(msg) {
  let base_fields = [
    #("title", json.string(title)),
    #("description", json.string(description)),
  ]
  let fields = case color {
    option.Some(c) ->
      list.append(base_fields, [
        #("color", json.string(card.color_to_string(c))),
      ])
    option.None -> base_fields
  }
  let fields = case parent_card_id {
    option.Some(id) -> list.append(fields, [#("parent_card_id", json.int(id))])
    option.None -> fields
  }
  let body = json.object(fields)
  let decoder = decode.field("card", card_codec.card_decoder(), decode.success)
  core.request(
    core.Patch,
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
    core.Delete,
    "/api/v1/cards/" <> int.to_string(card_id),
    option.None,
    to_msg,
  )
}

/// Activate a card subtree and return the number of tasks released to the Pool.
pub fn activate_card(
  card_id: Int,
  to_msg: fn(ApiResult(contracts.CardActionResponse)) -> msg,
) -> Effect(msg) {
  let decoder = card_action_response_decoder()
  core.request(
    core.Post,
    "/api/v1/cards/" <> int.to_string(card_id) <> "/activate",
    option.Some(json.object([])),
    decoder,
    to_msg,
  )
}

/// Move a card under another card, or to the project root with `None`.
pub fn move_card(
  card_id: Int,
  parent_card_id: option.Option(Int),
  to_msg: fn(ApiResult(contracts.CardActionResponse)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("parent_card_id", case parent_card_id {
        option.Some(id) -> json.int(id)
        option.None -> json.null()
      }),
    ])
  core.request(
    core.Post,
    "/api/v1/cards/" <> int.to_string(card_id) <> "/move",
    option.Some(body),
    card_action_response_decoder(),
    to_msg,
  )
}

/// List all tasks belonging to a card.
pub fn list_card_tasks(
  card_id: Int,
  to_msg: fn(ApiResult(List(Task))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "tasks",
      decode.list(task_codec.task_decoder()),
      decode.success,
    )
  core.request(
    core.Get,
    "/api/v1/cards/" <> int.to_string(card_id) <> "/tasks",
    option.None,
    decoder,
    to_msg,
  )
}

/// List all notes belonging to a card.
pub fn get_card_notes(
  card_id: Int,
  to_msg: fn(ApiResult(List(Note))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "notes",
      decode.list(note_codec.note_decoder()),
      decode.success,
    )
  core.request(
    core.Get,
    "/api/v1/cards/" <> int.to_string(card_id) <> "/notes",
    option.None,
    decoder,
    to_msg,
  )
}

/// Create a note for a card.
pub fn create_card_note(
  card_id: Int,
  content: String,
  to_msg: fn(ApiResult(Note)) -> msg,
) -> Effect(msg) {
  create_card_note_with_url(card_id, content, option.None, to_msg)
}

/// Create a note for a card with an optional explicit URL.
pub fn create_card_note_with_url(
  card_id: Int,
  content: String,
  url: option.Option(String),
  to_msg: fn(ApiResult(Note)) -> msg,
) -> Effect(msg) {
  let url_json = case url {
    option.Some(value) -> json.string(value)
    option.None -> json.null()
  }
  let body =
    json.object([#("content", json.string(content)), #("url", url_json)])
  let decoder = decode.field("note", note_codec.note_decoder(), decode.success)
  core.request(
    core.Post,
    "/api/v1/cards/" <> int.to_string(card_id) <> "/notes",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Pin or unpin a card note.
pub fn set_card_note_pinned(
  card_id: Int,
  note_id: Int,
  pinned: Bool,
  to_msg: fn(ApiResult(Note)) -> msg,
) -> Effect(msg) {
  let method = case pinned {
    True -> core.Post
    False -> core.Delete
  }
  let body = case pinned {
    True -> option.Some(json.object([]))
    False -> option.None
  }
  let decoder = decode.field("note", note_codec.note_decoder(), decode.success)
  core.request(
    method,
    "/api/v1/cards/"
      <> int.to_string(card_id)
      <> "/notes/"
      <> int.to_string(note_id)
      <> "/pin",
    body,
    decoder,
    to_msg,
  )
}

/// Delete a note from a card.
pub fn delete_card_note(
  card_id: Int,
  note_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/cards/"
      <> int.to_string(card_id)
      <> "/notes/"
      <> int.to_string(note_id),
    option.None,
    to_msg,
  )
}

fn card_action_response_decoder() -> decode.Decoder(
  contracts.CardActionResponse,
) {
  use card_id <- decode.field("card_id", decode.int)
  use pool_impact <- decode.field("pool_impact", decode.int)
  use pool_open_after <- decode.optional_field(
    "pool_open_after",
    pool_impact,
    decode.int,
  )
  use healthy_pool_limit <- decode.optional_field(
    "healthy_pool_limit",
    20,
    decode.int,
  )
  use pool_health_raw <- decode.optional_field(
    "pool_health",
    "within_healthy_limit",
    decode.string,
  )
  let pool_health = case contracts.pool_health_from_string(pool_health_raw) {
    Ok(health) -> health
    Error(_) -> contracts.PoolWithinHealthyLimit
  }
  decode.success(contracts.CardActionResponse(
    card_id: card_id,
    pool_impact: pool_impact,
    pool_open_after: pool_open_after,
    healthy_pool_limit: healthy_pool_limit,
    pool_health: pool_health,
  ))
}
