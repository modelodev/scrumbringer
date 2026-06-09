import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import scrumbringer_server/http/milestones/payloads

pub fn decode_create_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Sprint 1\",\"description\":\"Scope\"}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreatePayload(
    name: "Sprint 1",
    description: Some("Scope"),
  )) = payloads.decode_create(dynamic)
}

pub fn decode_create_payload_defaults_description_test() {
  let assert Ok(dynamic) = json.parse("{\"name\":\"Sprint 1\"}", decode.dynamic)

  let assert Ok(payloads.CreatePayload(name: "Sprint 1", description: None)) =
    payloads.decode_create(dynamic)
}

pub fn decode_patch_payload_test() {
  let assert Ok(dynamic) =
    json.parse("{\"name\":\"Sprint 2\",\"description\":null}", decode.dynamic)

  let assert Ok(payloads.PatchPayload(name: Some("Sprint 2"), description: None)) =
    payloads.decode_patch(dynamic)
}

pub fn decode_patch_payload_rejects_wrong_description_type_test() {
  let assert Ok(dynamic) = json.parse("{\"description\":123}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_patch(dynamic)
}
