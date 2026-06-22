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
//// - **domain/note/note_codec.gleam**: Provides note decoder
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/note/entity.{type Note}
import domain/note/note_codec
import scrumbringer_client/api/core

// =============================================================================
// Task Notes API Functions
// =============================================================================

/// List notes for a task.
pub fn list_task_notes(
  task_id: Int,
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
  to_msg: fn(ApiResult(Note)) -> msg,
) -> Effect(msg) {
  add_task_note_with_url(task_id, content, option.None, to_msg)
}

/// Add a note to a task with an optional explicit URL.
pub fn add_task_note_with_url(
  task_id: Int,
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
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Pin or unpin a task note.
pub fn set_task_note_pinned(
  task_id: Int,
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
    "/api/v1/tasks/"
      <> int.to_string(task_id)
      <> "/notes/"
      <> int.to_string(note_id)
      <> "/pin",
    body,
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
