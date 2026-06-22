//// Database operations for task notes.
////
//// Task notes allow users to add comments and discussion threads to tasks.
//// Notes are stored with their author and timestamp for audit purposes.

import domain/task.{type TaskNote, TaskNote}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/service_error.{
  type ServiceError, DbError, NotFound,
}

/// Lists all notes for a task, ordered by creation time.
///
/// ## Example
/// ```gleam
/// case task_notes_db.list_notes_for_task(db, task_id) {
///   Ok(notes) -> render_notes(notes)
///   Error(_) -> Error(DatabaseError)
/// }
/// ```
pub fn list_notes_for_task(
  db: pog.Connection,
  task_id: Int,
) -> Result(List(TaskNote), ServiceError) {
  use returned <- result.try(
    sql.task_notes_list(db, task_id)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.map(note_from_list_row)
  |> Ok
}

/// Creates a new note on a task.
///
/// ## Example
/// ```gleam
/// case task_notes_db.create_note(db, task_id, user_id, "Looking into this") {
///   Ok(note) -> Ok(note.id)
///   Error(DbError(_)) -> Error(DatabaseError)
///   Error(UnexpectedEmptyResult) -> Error(InternalError)
/// }
/// ```
pub fn create_note(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  content: String,
  url: Option(String),
) -> Result(TaskNote, ServiceError) {
  case
    sql.task_notes_create(
      db,
      task_id,
      user_id,
      content,
      optional_url_value(url),
    )
  {
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(persisted_field.returned_row(
        rows,
        "task_notes.create_note",
      ))
      Ok(note_from_create_row(row))
    }
    Error(e) -> Error(DbError(e))
  }
}

/// Get a note for a task by ID.
pub fn get_note(
  db: pog.Connection,
  task_id: Int,
  note_id: Int,
) -> Result(TaskNote, ServiceError) {
  case sql.task_notes_get(db, task_id, note_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(note_from_get_row(row))
  }
}

/// Deletes a note by ID.
pub fn delete_note(
  db: pog.Connection,
  task_id: Int,
  note_id: Int,
) -> Result(Nil, ServiceError) {
  case sql.task_notes_delete(db, task_id, note_id) {
    Ok(pog.Returned(rows: [_row, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Updates whether a task note is pinned.
pub fn set_note_pinned(
  db: pog.Connection,
  task_id: Int,
  note_id: Int,
  pinned: Bool,
) -> Result(TaskNote, ServiceError) {
  case sql.task_notes_set_pinned(db, task_id, note_id, pinned) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(note_from_set_pinned_row(row))
  }
}

fn note_from_list_row(row: sql.TaskNotesListRow) -> TaskNote {
  note_from_fields(
    row.id,
    row.task_id,
    row.user_id,
    row.content,
    row.url,
    row.pinned,
    row.created_at,
    row.updated_at,
  )
}

fn note_from_create_row(row: sql.TaskNotesCreateRow) -> TaskNote {
  note_from_fields(
    row.id,
    row.task_id,
    row.user_id,
    row.content,
    row.url,
    row.pinned,
    row.created_at,
    row.updated_at,
  )
}

fn note_from_get_row(row: sql.TaskNotesGetRow) -> TaskNote {
  note_from_fields(
    row.id,
    row.task_id,
    row.user_id,
    row.content,
    row.url,
    row.pinned,
    row.created_at,
    row.updated_at,
  )
}

fn note_from_set_pinned_row(row: sql.TaskNotesSetPinnedRow) -> TaskNote {
  note_from_fields(
    row.id,
    row.task_id,
    row.user_id,
    row.content,
    row.url,
    row.pinned,
    row.created_at,
    row.updated_at,
  )
}

fn note_from_fields(
  id: Int,
  task_id: Int,
  user_id: Int,
  content: String,
  url: String,
  pinned: Bool,
  created_at: String,
  updated_at: String,
) -> TaskNote {
  TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    url: optional_string(url),
    pinned: pinned,
    created_at: created_at,
    updated_at: updated_at,
  )
}

fn optional_url_value(url: Option(String)) -> String {
  case url {
    Some(value) -> value
    None -> ""
  }
}

fn optional_string(value: String) -> Option(String) {
  case value {
    "" -> None
    _ -> Some(value)
  }
}
