import gleam/list
import gleam/result
import pog
import scrumbringer_server/sql

pub type TaskNote {
  TaskNote(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
}

pub type CreateNoteError {
  DbError(pog.QueryError)
  UnexpectedEmptyResult
}

pub fn list_notes_for_task(
  db: pog.Connection,
  task_id: Int,
) -> Result(List(TaskNote), pog.QueryError) {
  use returned <- result.try(sql.task_notes_list(db, task_id))

  returned.rows
  |> list.map(note_from_list_row)
  |> Ok
}

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
