//// Database operations for task notes.
////
//// Task notes allow users to add comments and discussion threads to tasks.
//// Notes are stored with their author and timestamp for audit purposes.

import gleam/list
import gleam/result
import pog
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

/// Errors that can occur when creating a note.
pub type CreateNoteError {
  DbError(pog.QueryError)
  UnexpectedEmptyResult
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
) -> Result(List(TaskNote), pog.QueryError) {
  use returned <- result.try(sql.task_notes_list(db, task_id))

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
) -> Result(TaskNote, CreateNoteError) {
  case sql.task_notes_create(db, task_id, user_id, content) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(note_from_create_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(UnexpectedEmptyResult)
    Error(e) -> Error(DbError(e))
  }
}

fn note_from_list_row(row: sql.TaskNotesListRow) -> TaskNote {
  TaskNote(
    id: row.id,
    task_id: row.task_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
  )
}

fn note_from_create_row(row: sql.TaskNotesCreateRow) -> TaskNote {
  TaskNote(
    id: row.id,
    task_id: row.task_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
  )
}
