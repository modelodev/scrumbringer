//// Database operations for task notes.
////
//// Task notes allow users to add comments and discussion threads to tasks.
//// Notes are stored with their author and timestamp for audit purposes.

import domain/note/entity.{type Note, Note}
import domain/note/id as note_ids
import domain/note/subject.{TaskNoteSubject}
import domain/project/id as project_ids
import domain/task/id as task_ids
import domain/user/id as user_ids
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/persisted_role
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
) -> Result(List(Note), ServiceError) {
  use returned <- result.try(
    sql.task_notes_list(db, task_id)
    |> result.map_error(DbError),
  )

  list.try_map(returned.rows, note_from_list_row)
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
) -> Result(Note, ServiceError) {
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
      note_from_create_row(row)
    }
    Error(e) -> Error(DbError(e))
  }
}

/// Get a note for a task by ID.
pub fn get_note(
  db: pog.Connection,
  task_id: Int,
  note_id: Int,
) -> Result(Note, ServiceError) {
  case sql.task_notes_get(db, task_id, note_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> note_from_get_row(row)
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
) -> Result(Note, ServiceError) {
  case sql.task_notes_set_pinned(db, task_id, note_id, pinned) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> note_from_set_pinned_row(row)
  }
}

fn note_from_list_row(row: sql.TaskNotesListRow) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    task_id: row.task_id,
    project_id: row.project_id,
    user_id: row.user_id,
    content: row.content,
    url: row.url,
    pinned: row.pinned,
    created_at: row.created_at,
    updated_at: row.updated_at,
    author_email: row.author_email,
    author_project_role: row.author_project_role,
    author_org_role: row.author_org_role,
  )
}

fn note_from_create_row(
  row: sql.TaskNotesCreateRow,
) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    task_id: row.task_id,
    project_id: row.project_id,
    user_id: row.user_id,
    content: row.content,
    url: row.url,
    pinned: row.pinned,
    created_at: row.created_at,
    updated_at: row.updated_at,
    author_email: row.author_email,
    author_project_role: row.author_project_role,
    author_org_role: row.author_org_role,
  )
}

fn note_from_get_row(row: sql.TaskNotesGetRow) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    task_id: row.task_id,
    project_id: row.project_id,
    user_id: row.user_id,
    content: row.content,
    url: row.url,
    pinned: row.pinned,
    created_at: row.created_at,
    updated_at: row.updated_at,
    author_email: row.author_email,
    author_project_role: row.author_project_role,
    author_org_role: row.author_org_role,
  )
}

fn note_from_set_pinned_row(
  row: sql.TaskNotesSetPinnedRow,
) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    task_id: row.task_id,
    project_id: row.project_id,
    user_id: row.user_id,
    content: row.content,
    url: row.url,
    pinned: row.pinned,
    created_at: row.created_at,
    updated_at: row.updated_at,
    author_email: row.author_email,
    author_project_role: row.author_project_role,
    author_org_role: row.author_org_role,
  )
}

fn note_from_fields(
  id id: Int,
  task_id task_id: Int,
  project_id project_id: Int,
  user_id user_id: Int,
  content content: String,
  url url_raw: String,
  pinned pinned: Bool,
  created_at created_at: String,
  updated_at updated_at: String,
  author_email author_email: String,
  author_project_role author_project_role_raw: String,
  author_org_role author_org_role_raw: String,
) -> Result(Note, ServiceError) {
  use author_project_role <- result.try(
    persisted_role.optional_project_role_service_error(
      author_project_role_raw,
      "Invalid persisted author project role",
    ),
  )
  use author_org_role <- result.try(persisted_role.org_role_service_error(
    author_org_role_raw,
    "Invalid persisted author org role",
  ))

  Ok(Note(
    id: note_ids.new(id),
    project_id: project_ids.new(project_id),
    subject: TaskNoteSubject(task_ids.new(task_id)),
    user_id: user_ids.new(user_id),
    content: content,
    url: optional_string(url_raw),
    pinned: pinned,
    created_at: created_at,
    updated_at: updated_at,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
  ))
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
