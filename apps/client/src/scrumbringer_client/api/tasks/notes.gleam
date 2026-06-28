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

import gleam/int
import gleam/option

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/note/entity.{type Note}
import scrumbringer_client/api/notes as note_api

// =============================================================================
// Task Notes API Functions
// =============================================================================

/// List notes for a task.
pub fn list_task_notes(
  task_id: Int,
  to_msg: fn(ApiResult(List(Note))) -> msg,
) -> Effect(msg) {
  note_api.list(task_notes_path(task_id), to_msg)
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
  note_api.create(task_notes_path(task_id), content, url, to_msg)
}

/// Pin or unpin a task note.
pub fn set_task_note_pinned(
  task_id: Int,
  note_id: Int,
  pinned: Bool,
  to_msg: fn(ApiResult(Note)) -> msg,
) -> Effect(msg) {
  note_api.set_pinned(task_note_pin_path(task_id, note_id), pinned, to_msg)
}

/// Delete a note from a task.
pub fn delete_task_note(
  task_id: Int,
  note_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  note_api.delete(task_note_path(task_id, note_id), to_msg)
}

fn task_notes_path(task_id: Int) -> String {
  "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes"
}

fn task_note_path(task_id: Int, note_id: Int) -> String {
  task_notes_path(task_id) <> "/" <> int.to_string(note_id)
}

fn task_note_pin_path(task_id: Int, note_id: Int) -> String {
  task_note_path(task_id, note_id) <> "/pin"
}
