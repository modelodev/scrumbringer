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
import domain/metrics.{
  type CardModalMetrics, type ModalExecutionHealth, type WorkflowBreakdown,
  CardModalMetrics, ModalExecutionHealth, WorkflowBreakdown,
}
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

pub fn get_card_metrics(
  card_id: Int,
  to_msg: fn(ApiResult(CardModalMetrics)) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/cards/" <> int.to_string(card_id) <> "?include=metrics",
    option.None,
    decode.field("metrics", card_metrics_decoder(), decode.success),
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

fn card_metrics_decoder() -> decode.Decoder(CardModalMetrics) {
  use progress <- decode.field("progress", card_progress_decoder())
  let #(tasks_total, tasks_completed, tasks_percent) = progress

  use states <- decode.field("states", card_states_decoder())
  let #(tasks_available, tasks_claimed, tasks_ongoing) = states

  use health <- decode.field("health", card_health_decoder())
  use workflows <- decode.field("workflows", card_workflows_decoder())
  let #(items, most_activated) = workflows

  decode.success(CardModalMetrics(
    tasks_total: tasks_total,
    tasks_completed: tasks_completed,
    tasks_percent: tasks_percent,
    tasks_available: tasks_available,
    tasks_claimed: tasks_claimed,
    tasks_ongoing: tasks_ongoing,
    health: health,
    workflows: items,
    most_activated: most_activated,
  ))
}

fn card_progress_decoder() -> decode.Decoder(#(Int, Int, Int)) {
  use tasks_total <- decode.field("tasks_total", decode.int)
  use tasks_completed <- decode.field("tasks_completed", decode.int)
  use tasks_percent <- decode.field("tasks_percent", decode.int)
  decode.success(#(tasks_total, tasks_completed, tasks_percent))
}

fn card_states_decoder() -> decode.Decoder(#(Int, Int, Int)) {
  use available <- decode.field("available", decode.int)
  use claimed <- decode.field("claimed", decode.int)
  use ongoing <- decode.field("ongoing", decode.int)
  decode.success(#(available, claimed, ongoing))
}

fn card_health_decoder() -> decode.Decoder(ModalExecutionHealth) {
  use avg_rebotes <- decode.field("avg_rebotes", decode.int)
  use avg_pool_lifetime_s <- decode.field("avg_pool_lifetime_s", decode.int)
  use avg_executors <- decode.field("avg_executors", decode.int)
  decode.success(ModalExecutionHealth(
    avg_rebotes: avg_rebotes,
    avg_pool_lifetime_s: avg_pool_lifetime_s,
    avg_executors: avg_executors,
  ))
}

fn card_workflow_breakdown_decoder() -> decode.Decoder(WorkflowBreakdown) {
  use name <- decode.field("name", decode.string)
  use count <- decode.field("count", decode.int)
  decode.success(WorkflowBreakdown(name:, count:))
}

fn card_workflows_decoder() -> decode.Decoder(
  #(List(WorkflowBreakdown), option.Option(String)),
) {
  use items <- decode.field(
    "items",
    decode.list(card_workflow_breakdown_decoder()),
  )
  use most_activated <- decode.field(
    "most_activated",
    decode.optional(decode.string),
  )
  decode.success(#(items, most_activated))
}
