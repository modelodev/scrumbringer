//// Database operations for card notes.
////
//// Card notes provide context and decisions at the card level.

import domain/org_role
import domain/project_role
import gleam/list
import gleam/option.{type Option}
import gleam/result
import pog
import scrumbringer_server/services/persisted_field
import scrumbringer_server/services/persisted_role
import scrumbringer_server/services/service_error.{
  type ServiceError, DbError, NotFound,
}
import scrumbringer_server/sql

/// A note attached to a card.
pub type CardNote {
  CardNote(
    id: Int,
    card_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
    // AC20: Author info for tooltip
    author_email: String,
    author_project_role: Option(project_role.ProjectRole),
    author_org_role: org_role.OrgRole,
  )
}

/// Lists all notes for a card, ordered by creation time.
pub fn list_notes_for_card(
  db: pog.Connection,
  card_id: Int,
) -> Result(List(CardNote), ServiceError) {
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
) -> Result(CardNote, ServiceError) {
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
) -> Result(CardNote, ServiceError) {
  case sql.card_notes_create(db, card_id, user_id, content) {
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

fn note_from_list_row(
  row: sql.CardNotesListRow,
) -> Result(CardNote, ServiceError) {
  note_from_fields(
    id: row.id,
    card_id: row.card_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
    author_email: row.author_email,
    author_project_role: row.author_project_role,
    author_org_role: row.author_org_role,
  )
}

fn note_from_create_row(
  row: sql.CardNotesCreateRow,
) -> Result(CardNote, ServiceError) {
  note_from_fields(
    id: row.id,
    card_id: row.card_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
    author_email: row.author_email,
    author_project_role: row.author_project_role,
    author_org_role: row.author_org_role,
  )
}

fn note_from_get_row(row: sql.CardNotesGetRow) -> Result(CardNote, ServiceError) {
  note_from_fields(
    id: row.id,
    card_id: row.card_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
    author_email: row.author_email,
    author_project_role: row.author_project_role,
    author_org_role: row.author_org_role,
  )
}

fn note_from_fields(
  id id: Int,
  card_id card_id: Int,
  user_id user_id: Int,
  content content: String,
  created_at created_at: String,
  author_email author_email: String,
  author_project_role author_project_role_raw: String,
  author_org_role author_org_role_raw: String,
) -> Result(CardNote, ServiceError) {
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

  Ok(CardNote(
    id: id,
    card_id: card_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
  ))
}
