//// Card JSON decoders.

import gleam/dynamic/decode
import gleam/option

import domain/card.{
  type Card, type CardColor, type CardPhase, Card, Draft, parse_color,
  parse_state,
}
import domain/due_date as due_date_domain

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

fn optional_due_date_decoder() -> decode.Decoder(option.Option(String)) {
  use raw <- decode.then(decode.optional(decode.string))
  case raw {
    option.None | option.Some("") -> decode.success(option.None)
    option.Some(value) ->
      case due_date_domain.parse(value) {
        Ok(parsed) ->
          decode.success(option.Some(due_date_domain.to_string(parsed)))
        Error(_) -> decode.failure(option.None, "DueDate")
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
  use closed_count <- decode.field("closed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use due_date <- decode.optional_field(
    "due_date",
    option.None,
    optional_due_date_decoder(),
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
    closed_count: closed_count,
    created_by: created_by,
    created_at: created_at,
    due_date: due_date,
    has_new_notes: has_new_notes,
  ))
}
