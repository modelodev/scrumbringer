import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import domain/card
import scrumbringer_server/http/cards/payloads

pub fn decode_card_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"title\":\"Roadmap\",\"description\":\"Plan\",\"color\":\"blue\",\"parent_card_id\":42}",
      decode.dynamic,
    )

  let assert Ok(payloads.CardPayload(
    title: "Roadmap",
    description: Some("Plan"),
    color: Some(card.Blue),
    parent_card_id: Some(42),
  )) = payloads.decode_card(dynamic)
}

pub fn decode_card_payload_defaults_optional_fields_test() {
  let assert Ok(dynamic) = json.parse("{\"title\":\"Roadmap\"}", decode.dynamic)

  let assert Ok(payloads.CardPayload(
    title: "Roadmap",
    description: None,
    color: None,
    parent_card_id: None,
  )) = payloads.decode_card(dynamic)
}

pub fn decode_card_payload_rejects_invalid_color_test() {
  let assert Ok(dynamic) =
    json.parse("{\"title\":\"Roadmap\",\"color\":\"cyan\"}", decode.dynamic)

  let assert Error(payloads.InvalidColor) = payloads.decode_card(dynamic)
}

pub fn decode_card_payload_rejects_invalid_shape_test() {
  let assert Ok(dynamic) =
    json.parse("{\"description\":\"Plan\"}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_card(dynamic)
}
