//// Task notes API functions.
////
//// ## Mission
////
//// Provides API operations for task notes.
////
//// ## Responsibilities
////
//// - List notes for a task
//// - Add notes to a task
////
//// ## Relations
////
//// - **domain/task/task_codec.gleam**: Provides note decoder
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/task.{type TaskNote}
import domain/task/task_codec as decoders
import scrumbringer_client/api/core

// =============================================================================
// Task Notes API Functions
// =============================================================================

/// List notes for a task.
pub fn list_task_notes(
  task_id: Int,
  to_msg: fn(ApiResult(List(TaskNote))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("notes", decode.list(decoders.note_decoder()), decode.success)
  core.request(
    core.Get,
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    option.None,
    decoder,
    to_msg,
  )
}

/// Add a note to a task.
pub fn add_task_note(
  task_id: Int,
  content: String,
  to_msg: fn(ApiResult(TaskNote)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("content", json.string(content))])
  let decoder = decode.field("note", decoders.note_decoder(), decode.success)

  core.request(
    core.Post,
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Delete a note from a task.
pub fn delete_task_note(
  task_id: Int,
  note_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/tasks/"
      <> int.to_string(task_id)
      <> "/notes/"
      <> int.to_string(note_id),
    option.None,
    to_msg,
  )
}
