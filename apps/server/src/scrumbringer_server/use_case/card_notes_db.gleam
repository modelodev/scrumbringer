//// Database operations for card notes.
////
//// Card notes provide context and decisions at the card level.

import domain/card/id as card_ids
import domain/note/entity.{type Note, Note}
import domain/note/id as note_ids
import domain/note/subject.{CardNoteSubject}
import domain/project/id as project_ids
import domain/user/id as user_ids
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/audit_events_db
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/persisted_role
import scrumbringer_server/use_case/service_error.{
  type ServiceError, DbError, NotFound,
}

/// Lists all notes for a card, ordered by creation time.
pub fn list_notes_for_card(
  db: pog.Connection,
  card_id: Int,
) -> Result(List(Note), ServiceError) {
  use returned <- result.try(
    sql.card_notes_list(db, card_id)
    |> result.map_error(DbError),
  )

  list.try_map(returned.rows, note_from_list_row)
}

/// Get a note for a card by ID.
pub fn get_note(
  db: pog.Connection,
  card_id: Int,
  note_id: Int,
) -> Result(Note, ServiceError) {
  case sql.card_notes_get(db, card_id, note_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> note_from_get_row(row)
  }
}

/// Creates a new note on a card.
pub fn create_note(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
  content: String,
  url: Option(String),
) -> Result(Note, ServiceError) {
  case
    sql.card_notes_create(
      db,
      card_id,
      user_id,
      content,
      optional_url_value(url),
    )
  {
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(persisted_field.returned_row(
        rows,
        "card_notes.create_note",
      ))
      note_from_create_row(row)
    }
    Error(e) -> Error(DbError(e))
  }
}

/// Creates a card note and records the user-visible activity event.
pub fn create_note_with_audit(
  db: pog.Connection,
  org_id: Int,
  card_id: Int,
  user_id: Int,
  content: String,
  url: Option(String),
) -> Result(Note, ServiceError) {
  pog.transaction(db, fn(tx) {
    use note <- result.try(create_note(tx, card_id, user_id, content, url))
    use _ <- result.try(insert_note_audit(
      tx,
      org_id,
      note,
      card_id,
      user_id,
      audit_events_db.NoteCreated,
    ))
    Ok(note)
  })
  |> result.map_error(transaction_error_to_service_error)
}

/// Deletes a note by ID.
pub fn delete_note(
  db: pog.Connection,
  card_id: Int,
  note_id: Int,
) -> Result(Nil, ServiceError) {
  case sql.card_notes_delete(db, card_id, note_id) {
    Ok(pog.Returned(rows: [_row, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Updates whether a card note is pinned.
pub fn set_note_pinned(
  db: pog.Connection,
  card_id: Int,
  note_id: Int,
  pinned: Bool,
) -> Result(Note, ServiceError) {
  case sql.card_notes_set_pinned(db, card_id, note_id, pinned) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> note_from_set_pinned_row(row)
  }
}

/// Updates whether a card note is pinned and records the activity event.
pub fn set_note_pinned_with_audit(
  db: pog.Connection,
  org_id: Int,
  card_id: Int,
  note_id: Int,
  actor_user_id: Int,
  pinned: Bool,
) -> Result(Note, ServiceError) {
  pog.transaction(db, fn(tx) {
    use note <- result.try(set_note_pinned(tx, card_id, note_id, pinned))
    use _ <- result.try(
      insert_note_audit(tx, org_id, note, card_id, actor_user_id, case pinned {
        True -> audit_events_db.NotePinned
        False -> audit_events_db.NoteUnpinned
      }),
    )
    Ok(note)
  })
  |> result.map_error(transaction_error_to_service_error)
}

fn note_from_list_row(row: sql.CardNotesListRow) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    card_id: row.card_id,
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

fn insert_note_audit(
  db: pog.Connection,
  org_id: Int,
  note: Note,
  card_id: Int,
  actor_user_id: Int,
  event_type: audit_events_db.EventType,
) -> Result(Nil, ServiceError) {
  audit_events_db.insert_for_card(
    db,
    org_id,
    project_ids.to_int(note.project_id),
    card_id,
    actor_user_id,
    event_type,
  )
  |> result.map_error(DbError)
}

fn transaction_error_to_service_error(
  error: pog.TransactionError(ServiceError),
) -> ServiceError {
  case error {
    pog.TransactionRolledBack(error) -> error
    pog.TransactionQueryError(error) -> DbError(error)
  }
}

fn note_from_create_row(
  row: sql.CardNotesCreateRow,
) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    card_id: row.card_id,
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

fn note_from_get_row(row: sql.CardNotesGetRow) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    card_id: row.card_id,
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
  row: sql.CardNotesSetPinnedRow,
) -> Result(Note, ServiceError) {
  note_from_fields(
    id: row.id,
    card_id: row.card_id,
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
  card_id card_id: Int,
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
    subject: CardNoteSubject(card_ids.new(card_id)),
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
