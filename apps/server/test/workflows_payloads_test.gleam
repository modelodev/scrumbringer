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
      "{\"name\":\"Updated\",\"description\":null,\"active\":true}",
      decode.dynamic,
    )

  let assert Ok(payloads.UpdatePayload(
    name: Some("Updated"),
    description: None,
    active: Some(True),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_decodes_inactive_flag_test() {
  let assert Ok(dynamic) = json.parse("{\"active\":false}", decode.dynamic)

  let assert Ok(payloads.UpdatePayload(
    name: None,
    description: None,
    active: Some(False),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_rejects_wrong_active_type_test() {
  let assert Ok(dynamic) = json.parse("{\"active\":\"false\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_rejects_numeric_active_flag_test() {
  let assert Ok(dynamic) = json.parse("{\"active\":0}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_update(dynamic)
}
