//// Database operations for card notes.
////
//// Card notes provide context and decisions at the card level.

import gleam/list
import gleam/option.{type Option}
import gleam/result
import helpers/option as option_helpers
import pog
import scrumbringer_server/services/service_error.{
  type ServiceError, DbError, NotFound, Unexpected,
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
    author_project_role: Option(String),
    author_org_role: String,
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

  returned.rows
  |> list.map(note_from_list_row)
  |> Ok
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
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(note_from_get_row(row))
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
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(note_from_create_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(Unexpected("empty_result"))
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

fn note_from_list_row(row: sql.CardNotesListRow) -> CardNote {
  CardNote(
    id: row.id,
    card_id: row.card_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
    author_email: row.author_email,
    author_project_role: option_helpers.string_to_option(
      row.author_project_role,
    ),
    author_org_role: row.author_org_role,
  )
}

fn note_from_create_row(row: sql.CardNotesCreateRow) -> CardNote {
  CardNote(
    id: row.id,
    card_id: row.card_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
    author_email: row.author_email,
    author_project_role: option_helpers.string_to_option(
      row.author_project_role,
    ),
    author_org_role: row.author_org_role,
  )
}

fn note_from_get_row(row: sql.CardNotesGetRow) -> CardNote {
  CardNote(
    id: row.id,
    card_id: row.card_id,
    user_id: row.user_id,
    content: row.content,
    created_at: row.created_at,
    author_email: row.author_email,
    author_project_role: option_helpers.string_to_option(
      row.author_project_role,
    ),
    author_org_role: row.author_org_role,
  )
}
