//// Card JSON decoders.

import gleam/dynamic/decode
import gleam/option

import domain/card.{
  type Card, type CardNote, type CardState, Card, CardNote, state_from_string,
}

/// Decoder for CardState.
pub fn card_state_decoder() -> decode.Decoder(CardState) {
  decode.string |> decode.map(state_from_string)
}

fn color_decoder() -> decode.Decoder(option.Option(String)) {
  use color_str <- decode.then(decode.string)
  case color_str {
    "" -> decode.success(option.None)
    c -> decode.success(option.Some(c))
  }
}

/// Decoder for Card.
pub fn card_decoder() -> decode.Decoder(Card) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use color <- decode.field("color", color_decoder())
  use state <- decode.field("state", card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use has_new_notes <- decode.optional_field(
    "has_new_notes",
    False,
    decode.bool,
  )
  decode.success(Card(
    id: id,
    project_id: project_id,
    title: title,
    description: description,
    color: color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
    has_new_notes: has_new_notes,
  ))
}

/// Decoder for CardNote.
pub fn card_note_decoder() -> decode.Decoder(CardNote) {
  use id <- decode.field("id", decode.int)
  use card_id <- decode.field("card_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use content <- decode.field("content", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use author_email <- decode.field("author_email", decode.string)
  use author_project_role <- decode.optional_field(
    "author_project_role",
    option.None,
    decode.optional(decode.string),
  )
  use author_org_role <- decode.field("author_org_role", decode.string)
  decode.success(CardNote(
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
