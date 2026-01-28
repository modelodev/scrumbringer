//// Database operations for card notes.
////
//// Card notes provide context and decisions at the card level.

import gleam/list
import gleam/result
import pog
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
    author_role: String,
  )
}

/// Errors that can occur when creating a note.
pub type CreateNoteError {
  CreateDbError(pog.QueryError)
  CreateUnexpectedEmptyResult
}

/// Errors that can occur when reading a note.
pub type GetNoteError {
  GetDbError(pog.QueryError)
  GetNoteNotFound
}

/// Errors that can occur when deleting a note.
pub type DeleteNoteError {
  DeleteDbError(pog.QueryError)
  DeleteNoteNotFound
}

/// Lists all notes for a card, ordered by creation time.
pub fn list_notes_for_card(
  db: pog.Connection,
  card_id: Int,
) -> Result(List(CardNote), pog.QueryError) {
  use returned <- result.try(sql.card_notes_list(db, card_id))

  returned.rows
  |> list.map(note_from_list_row)
  |> Ok
}

/// Get a note for a card by ID.
pub fn get_note(
  db: pog.Connection,
  card_id: Int,
  note_id: Int,
) -> Result(CardNote, GetNoteError) {
  case sql.card_notes_get(db, card_id, note_id) {
    Error(e) -> Error(GetDbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(GetNoteNotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(note_from_get_row(row))
  }
}

/// Creates a new note on a card.
pub fn create_note(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
  content: String,
) -> Result(CardNote, CreateNoteError) {
  case sql.card_notes_create(db, card_id, user_id, content) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(note_from_create_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(CreateUnexpectedEmptyResult)
    Error(e) -> Error(CreateDbError(e))
  }
}

/// Deletes a note by ID.
pub fn delete_note(
  db: pog.Connection,
  card_id: Int,
  note_id: Int,
) -> Result(Nil, DeleteNoteError) {
  case sql.card_notes_delete(db, card_id, note_id) {
    Ok(pog.Returned(rows: [_row, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(DeleteNoteNotFound)
    Error(e) -> Error(DeleteDbError(e))
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
    author_role: row.author_role,
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
    author_role: row.author_role,
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
    author_role: row.author_role,
  )
}
