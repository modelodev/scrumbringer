//// Card JSON decoders.

import gleam/dynamic/decode
import gleam/option

import domain/card.{
  type Card, type CardColor, type CardNote, type CardPhase, Card, CardNote,
  Draft, parse_color, parse_state,
}
import domain/org_role/org_role_codec
import domain/project_role/project_role_codec

/// Decoder for CardPhase.
pub fn card_state_decoder() -> decode.Decoder(CardPhase) {
  use raw <- decode.then(decode.string)
  case parse_state(raw) {
    Ok(state) -> decode.success(state)
    Error(_) -> decode.failure(Draft, "CardPhase")
  }
}

pub fn optional_color_decoder() -> decode.Decoder(option.Option(CardColor)) {
  use raw <- decode.then(decode.optional(decode.string))
  case raw {
    option.None -> decode.success(option.None)
    option.Some("") -> decode.success(option.None)
    option.Some(value) ->
      case parse_color(value) {
        Ok(color) -> decode.success(option.Some(color))
        Error(_) -> decode.failure(option.None, "CardColor")
      }
  }
}

/// Decoder for Card.
pub fn card_decoder() -> decode.Decoder(Card) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use parent_card_id <- decode.optional_field(
    "parent_card_id",
    option.None,
    decode.optional(decode.int),
  )
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use color <- decode.field("color", optional_color_decoder())
  use state <- decode.field("state", card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use due_date <- decode.optional_field(
    "due_date",
    option.None,
    decode.optional(decode.string),
  )
  use has_new_notes <- decode.optional_field(
    "has_new_notes",
    False,
    decode.bool,
  )
  decode.success(Card(
    id: id,
    project_id: project_id,
    parent_card_id: parent_card_id,
    title: title,
    description: description,
    color: color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
    due_date: due_date,
    has_new_notes: has_new_notes,
  ))
}

/// Decoder for CardNote.
pub fn card_note_decoder() -> decode.Decoder(CardNote) {
  use id <- decode.field("id", decode.int)
  use card_id <- decode.field("card_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use content <- decode.field("content", decode.string)
  use url <- decode.optional_field(
    "url",
    option.None,
    decode.optional(decode.string),
  )
  use pinned <- decode.optional_field("pinned", False, decode.bool)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.optional_field(
    "updated_at",
    created_at,
    decode.string,
  )
  use author_email <- decode.field("author_email", decode.string)
  use author_project_role <- decode.optional_field(
    "author_project_role",
    option.None,
    decode.optional(project_role_codec.project_role_decoder()),
  )
  use author_org_role <- decode.field(
    "author_org_role",
    org_role_codec.org_role_decoder(),
  )
  decode.success(CardNote(
    id: id,
    card_id: card_id,
    user_id: user_id,
    content: content,
    url: url,
    pinned: pinned,
    created_at: created_at,
    updated_at: updated_at,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
  ))
}
