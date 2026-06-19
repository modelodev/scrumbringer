//// JSON codec for card execution state.

import gleam/dynamic/decode
import gleam/json.{type Json}

import domain/card/id as card_id
import domain/card/state.{
  type ActivationSource, type CardClosedReason, type CardExecutionState,
  ActivatedByAncestor, Active, Closed, DirectActivation, Draft, ManuallyClosed,
  Rollup,
}
import domain/user/id as user_id

pub fn decoder() -> decode.Decoder(CardExecutionState) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "draft" -> decode.success(Draft)
    "active" -> {
      use activated_at <- decode.field("activated_at", decode.string)
      use activated_by <- decode.field("activated_by", decode.int)
      use source <- decode.field("source", activation_source_decoder())
      decode.success(Active(
        activated_at: activated_at,
        activated_by: user_id.new(activated_by),
        source: source,
      ))
    }
    "closed" -> {
      use reason <- decode.field("reason", closed_reason_decoder())
      use closed_at <- decode.field("closed_at", decode.string)
      use closed_by <- decode.field("closed_by", decode.int)
      decode.success(Closed(
        reason: reason,
        closed_at: closed_at,
        closed_by: user_id.new(closed_by),
      ))
    }
    _ -> decode.failure(Draft, "CardExecutionState")
  }
}

pub fn to_json(state: CardExecutionState) -> Json {
  case state {
    Draft ->
      json.object([
        #("type", json.string("draft")),
      ])
    Active(activated_at, activated_by, source) ->
      json.object([
        #("type", json.string("active")),
        #("activated_at", json.string(activated_at)),
        #("activated_by", json.int(user_id.to_int(activated_by))),
        #("source", activation_source_to_json(source)),
      ])
    Closed(reason, closed_at, closed_by) ->
      json.object([
        #("type", json.string("closed")),
        #("reason", closed_reason_to_json(reason)),
        #("closed_at", json.string(closed_at)),
        #("closed_by", json.int(user_id.to_int(closed_by))),
      ])
  }
}

fn activation_source_decoder() -> decode.Decoder(ActivationSource) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "direct_activation" -> decode.success(DirectActivation)
    "activated_by_ancestor" -> {
      use id <- decode.field("card_id", decode.int)
      decode.success(ActivatedByAncestor(card_id.new(id)))
    }
    _ -> decode.failure(DirectActivation, "ActivationSource")
  }
}

fn activation_source_to_json(source: ActivationSource) -> Json {
  case source {
    DirectActivation ->
      json.object([
        #("type", json.string("direct_activation")),
      ])
    ActivatedByAncestor(id) ->
      json.object([
        #("type", json.string("activated_by_ancestor")),
        #("card_id", json.int(card_id.to_int(id))),
      ])
  }
}

fn closed_reason_decoder() -> decode.Decoder(CardClosedReason) {
  use value <- decode.then(decode.string)
  case value {
    "rollup" -> decode.success(Rollup)
    "manually_closed" -> decode.success(ManuallyClosed)
    _ -> decode.failure(Rollup, "CardClosedReason")
  }
}

fn closed_reason_to_json(reason: CardClosedReason) -> Json {
  case reason {
    Rollup -> json.string("rollup")
    ManuallyClosed -> json.string("manually_closed")
  }
}
