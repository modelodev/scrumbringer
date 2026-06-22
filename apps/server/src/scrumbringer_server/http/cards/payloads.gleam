//// JSON payload decoder and validation for card endpoints.

import api/cards/contracts
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

import domain/card

pub type CardPayload {
  CardPayload(
    title: String,
    description: Option(String),
    color: Option(card.CardColor),
    parent_card_id: Option(Int),
    due_date: Option(String),
  )
}

pub type DecodeError {
  InvalidJson
  InvalidColor
}

pub fn decode_card(data: Dynamic) -> Result(CardPayload, DecodeError) {
  case contracts.decode_card_create(data) {
    Error(contracts.InvalidColor) -> Error(InvalidColor)
    Error(_) -> Error(InvalidJson)
    Ok(request) ->
      Ok(CardPayload(
        title: request.title,
        description: request.description,
        color: request.color,
        parent_card_id: request.parent_card_id,
        due_date: request.due_date,
      ))
  }
}
