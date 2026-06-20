//// Shared API contracts for card hierarchy endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}

import domain/card

pub type DepthScope {
  DepthScope(Int)
}

pub type CardScope {
  CardOnly
  CardChildren
  CardDescendants
}

pub type CardCreateRequest {
  CardCreateRequest(
    title: String,
    description: Option(String),
    color: Option(card.CardColor),
    parent_card_id: Option(Int),
  )
}

pub type CardMoveRequest {
  CardMoveRequest(parent_card_id: Option(Int))
}

pub type CardCloseRequest {
  CardCloseRequest(reason: String)
}

pub type CardActionResponse {
  CardActionResponse(
    card_id: Int,
    pool_impact: Int,
    pool_open_after: Int,
    healthy_pool_limit: Int,
    pool_health: PoolHealth,
  )
}

pub type PoolHealth {
  PoolWithinHealthyLimit
  PoolExceedsHealthyLimit
}

pub type DecodeError {
  InvalidJson
  InvalidColor
  InvalidScope
}

pub fn depth_scope_codec() -> decode.Decoder(DepthScope) {
  use depth <- decode.field("depth", decode.int)
  case depth > 0 {
    True -> decode.success(DepthScope(depth))
    False -> decode.failure(DepthScope(1), "DepthScope")
  }
}

pub fn card_scope_codec() -> decode.Decoder(CardScope) {
  use raw <- decode.field("scope", decode.string)
  case raw {
    "card" -> decode.success(CardOnly)
    "children" -> decode.success(CardChildren)
    "descendants" -> decode.success(CardDescendants)
    _ -> decode.failure(CardOnly, "CardScope")
  }
}

pub fn card_create_request_codec() -> decode.Decoder(CardCreateRequest) {
  use raw <- decode.then(card_create_raw_codec())
  case raw_to_create_request(raw) {
    Ok(request) -> decode.success(request)
    Error(_) ->
      decode.failure(
        CardCreateRequest(
          title: "",
          description: None,
          color: None,
          parent_card_id: None,
        ),
        "CardCreateRequest",
      )
  }
}

fn card_create_raw_codec() {
  use title <- decode.field("title", decode.string)
  use description <- decode.optional_field("description", "", decode.string)
  use color <- decode.optional_field("color", "", decode.string)
  use parent_card_id <- decode.optional_field(
    "parent_card_id",
    None,
    decode.optional(decode.int),
  )
  decode.success(#(title, description, color, parent_card_id))
}

fn raw_to_create_request(
  raw: #(String, String, String, Option(Int)),
) -> Result(CardCreateRequest, DecodeError) {
  let #(title, description, color, parent_card_id) = raw
  case parse_color(color) {
    Ok(parsed_color) ->
      Ok(CardCreateRequest(
        title: title,
        description: optional_string(description),
        color: parsed_color,
        parent_card_id: parent_card_id,
      ))
    Error(error) -> Error(error)
  }
}

pub fn card_move_request_codec() -> decode.Decoder(CardMoveRequest) {
  use parent_card_id <- decode.field(
    "parent_card_id",
    decode.optional(decode.int),
  )
  decode.success(CardMoveRequest(parent_card_id: parent_card_id))
}

pub fn card_close_request_codec() -> decode.Decoder(CardCloseRequest) {
  use reason <- decode.optional_field(
    "reason",
    "manually_closed",
    decode.string,
  )
  decode.success(CardCloseRequest(reason: reason))
}

pub fn decode_card_create(
  data: Dynamic,
) -> Result(CardCreateRequest, DecodeError) {
  case decode.run(data, card_create_raw_codec()) {
    Ok(raw) -> raw_to_create_request(raw)
    Error(_) -> Error(InvalidJson)
  }
}

pub fn decode_card_move(data: Dynamic) -> Result(CardMoveRequest, DecodeError) {
  decode.run(data, card_move_request_codec())
  |> result_from_decode
}

pub fn decode_card_close(data: Dynamic) -> Result(CardCloseRequest, DecodeError) {
  decode.run(data, card_close_request_codec())
  |> result_from_decode
}

pub fn action_response_to_json(response: CardActionResponse) -> Json {
  json.object([
    #("card_id", json.int(response.card_id)),
    #("pool_impact", json.int(response.pool_impact)),
    #("pool_open_after", json.int(response.pool_open_after)),
    #("healthy_pool_limit", json.int(response.healthy_pool_limit)),
    #("pool_health", json.string(pool_health_to_string(response.pool_health))),
  ])
}

pub fn pool_health_to_string(health: PoolHealth) -> String {
  case health {
    PoolWithinHealthyLimit -> "within_healthy_limit"
    PoolExceedsHealthyLimit -> "exceeds_healthy_limit"
  }
}

pub fn pool_health_from_string(value: String) -> Result(PoolHealth, DecodeError) {
  case value {
    "within_healthy_limit" -> Ok(PoolWithinHealthyLimit)
    "exceeds_healthy_limit" -> Ok(PoolExceedsHealthyLimit)
    _ -> Error(InvalidJson)
  }
}

fn result_from_decode(result: Result(a, b)) -> Result(a, DecodeError) {
  case result {
    Ok(value) -> Ok(value)
    Error(_) -> Error(InvalidJson)
  }
}

fn parse_color(raw: String) -> Result(Option(card.CardColor), DecodeError) {
  case card.parse_optional_color(raw) {
    Ok(color) -> Ok(color)
    Error(_) -> Error(InvalidColor)
  }
}

fn optional_string(value: String) -> Option(String) {
  case value {
    "" -> None
    other -> Some(other)
  }
}
