//// JSON payload decoder and validation for card endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}

import domain/card

pub type CardPayload {
  CardPayload(
    title: String,
    description: Option(String),
    color: Option(card.CardColor),
    milestone_id: Option(Int),
  )
}

pub type DecodeError {
  InvalidJson
  InvalidColor
}

pub fn decode_card(data: Dynamic) -> Result(CardPayload, DecodeError) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use color <- decode.optional_field("color", "", decode.string)
    use milestone_id <- decode.optional_field(
      "milestone_id",
      None,
      decode.optional(decode.int),
    )
    decode.success(#(title, description, color, milestone_id))
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(InvalidJson)
    Ok(#(title, description, color, milestone_id)) ->
      normalize_card_payload(title, description, color, milestone_id)
  }
}

fn normalize_card_payload(
  title: String,
  description: String,
  color: String,
  milestone_id: Option(Int),
) -> Result(CardPayload, DecodeError) {
  case validate_color(color) {
    Error(error) -> Error(error)
    Ok(validated_color) ->
      Ok(CardPayload(
        title: title,
        description: normalize_optional(description),
        color: validated_color,
        milestone_id: milestone_id,
      ))
  }
}

fn validate_color(color: String) -> Result(Option(card.CardColor), DecodeError) {
  case card.parse_optional_color(color) {
    Ok(parsed) -> Ok(parsed)
    Error(_) -> Error(InvalidColor)
  }
}

fn normalize_optional(value: String) -> Option(String) {
  case value {
    "" -> None
    other -> Some(other)
  }
}
