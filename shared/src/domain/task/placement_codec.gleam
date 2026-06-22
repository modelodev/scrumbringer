//// JSON codec for task placement.

import gleam/dynamic/decode
import gleam/json.{type Json}

import domain/card/id as card_id
import domain/task/placement.{type TaskPlacement, RootPool, UnderCard}

pub fn decoder() -> decode.Decoder(TaskPlacement) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "root_pool" -> decode.success(RootPool)
    "under_card" -> {
      use id <- decode.field("card_id", decode.int)
      decode.success(UnderCard(card_id.new(id)))
    }
    _ -> decode.failure(RootPool, "TaskPlacement")
  }
}

pub fn to_json(placement: TaskPlacement) -> Json {
  case placement {
    RootPool ->
      json.object([
        #("type", json.string("root_pool")),
      ])
    UnderCard(id) ->
      json.object([
        #("type", json.string("under_card")),
        #("card_id", json.int(card_id.to_int(id))),
      ])
  }
}
