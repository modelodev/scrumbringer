//// JSON codec for task placement.

import gleam/dynamic/decode
import gleam/json.{type Json}

import domain/card/id as card_id
import domain/task/placement.{type TaskPlacement, UnderCard}

pub fn decoder() -> decode.Decoder(TaskPlacement) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "under_card" -> {
      use id <- decode.field("card_id", decode.int)
      decode.success(UnderCard(card_id.new(id)))
    }
    _ -> decode.failure(UnderCard(card_id.new(0)), "TaskPlacement")
  }
}

pub fn to_json(placement: TaskPlacement) -> Json {
  case placement {
    UnderCard(id) ->
      json.object([
        #("type", json.string("under_card")),
        #("card_id", json.int(card_id.to_int(id))),
      ])
  }
}
