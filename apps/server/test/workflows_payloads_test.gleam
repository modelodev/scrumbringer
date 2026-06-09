import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import scrumbringer_server/http/workflows/payloads

pub fn decode_create_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Workflow\",\"description\":\"Rules\",\"active\":true}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreatePayload(
    name: "Workflow",
    description: "Rules",
    active: True,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_create_payload_defaults_optional_fields_test() {
  let assert Ok(dynamic) = json.parse("{\"name\":\"Workflow\"}", decode.dynamic)

  let assert Ok(payloads.CreatePayload(
    name: "Workflow",
    description: "",
    active: False,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_update_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Updated\",\"description\":null,\"active\":1}",
      decode.dynamic,
    )

  let assert Ok(payloads.UpdatePayload(
    name: Some("Updated"),
    description: None,
    active: Some(1),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_rejects_wrong_active_type_test() {
  let assert Ok(dynamic) = json.parse("{\"active\":true}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_update(dynamic)
}
