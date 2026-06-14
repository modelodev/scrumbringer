//// Database operations for task notes.
////
//// Task notes allow users to add comments and discussion threads to tasks.
//// Notes are stored with their author and timestamp for audit purposes.

import gleam/list
import gleam/result
import pog
import scrumbringer_server/services/persisted_field
import scrumbringer_server/services/service_error.{
  type ServiceError, DbError, NotFound,
}
import scrumbringer_server/sql

/// A note attached to a task.
pub type TaskNote {
  TaskNote(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
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
) -> Result(TaskNote, ServiceError) {
  case sql.task_notes_create(db, task_id, user_id, content) {
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

fn note_from_list_row(row: sql.TaskNotesListRow) -> TaskNote {
  note_from_fields(
    row.id,
    row.task_id,
    row.user_id,
    row.content,
    row.created_at,
  )
}

fn note_from_create_row(row: sql.TaskNotesCreateRow) -> TaskNote {
  note_from_fields(
    row.id,
    row.task_id,
    row.user_id,
    row.content,
    row.created_at,
  )
}

fn note_from_get_row(row: sql.TaskNotesGetRow) -> TaskNote {
  note_from_fields(
    row.id,
    row.task_id,
    row.user_id,
    row.content,
    row.created_at,
  )
}

fn note_from_fields(
  id: Int,
  task_id: Int,
  user_id: Int,
  content: String,
  created_at: String,
) -> TaskNote {
  TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
  )
}
