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
//// cards.list_card_tasks(card_id, CardTasksFetched)
//// ```

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/api/tasks/decoders as task_decoders

import domain/card.{type Card, type CardNote}
import domain/card/codec as card_codec
import domain/task.{type Task}

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
  color: option.Option(String),
  milestone_id: option.Option(Int),
  to_msg: fn(ApiResult(Card)) -> msg,
) -> Effect(msg) {
  let base_fields = [
    #("title", json.string(title)),
    #("description", json.string(description)),
  ]
  let fields = case color {
    option.Some(c) -> list.append(base_fields, [#("color", json.string(c))])
    option.None -> base_fields
  }
  let fields = case milestone_id {
    option.Some(id) -> list.append(fields, [#("milestone_id", json.int(id))])
    option.None -> fields
  }
  let body = json.object(fields)
  let decoder = decode.field("card", card_codec.card_decoder(), decode.success)
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
  let decoder = decode.field("card", card_codec.card_decoder(), decode.success)
  core.request(
    "GET",
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
    "PUT",
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
  color: option.Option(String),
  milestone_id: option.Option(Int),
  to_msg: fn(ApiResult(Card)) -> msg,
) -> Effect(msg) {
  let base_fields = [
    #("title", json.string(title)),
    #("description", json.string(description)),
  ]
  let fields = case color {
    option.Some(c) -> list.append(base_fields, [#("color", json.string(c))])
    option.None -> base_fields
  }
  let fields = case milestone_id {
    option.Some(id) -> list.append(fields, [#("milestone_id", json.int(id))])
    option.None -> fields
  }
  let body = json.object(fields)
  let decoder = decode.field("card", card_codec.card_decoder(), decode.success)
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

/// List all tasks belonging to a card.
pub fn list_card_tasks(
  card_id: Int,
  to_msg: fn(ApiResult(List(Task))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "tasks",
      decode.list(task_decoders.task_decoder()),
      decode.success,
    )
  core.request(
    "GET",
    "/api/v1/cards/" <> int.to_string(card_id) <> "/tasks",
    option.None,
    decoder,
    to_msg,
  )
}

/// List all notes belonging to a card.
pub fn get_card_notes(
  card_id: Int,
  to_msg: fn(ApiResult(List(CardNote))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "notes",
      decode.list(card_codec.card_note_decoder()),
      decode.success,
    )
  core.request(
    "GET",
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
  to_msg: fn(ApiResult(CardNote)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("content", json.string(content))])
  let decoder =
    decode.field("note", card_codec.card_note_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/cards/" <> int.to_string(card_id) <> "/notes",
    option.Some(body),
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
    "DELETE",
    "/api/v1/cards/"
      <> int.to_string(card_id)
      <> "/notes/"
      <> int.to_string(note_id),
    option.None,
    to_msg,
  )
}
