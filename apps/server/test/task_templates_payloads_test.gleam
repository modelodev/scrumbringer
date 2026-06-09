import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import scrumbringer_server/http/task_templates/payloads

pub fn decode_create_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Review\",\"description\":\"Auto\",\"type_id\":4,\"priority\":2}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreatePayload(
    name: "Review",
    description: "Auto",
    type_id: 4,
    priority: 2,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_create_payload_defaults_optional_fields_test() {
  let assert Ok(dynamic) =
    json.parse("{\"name\":\"Review\",\"type_id\":4}", decode.dynamic)

  let assert Ok(payloads.CreatePayload(
    name: "Review",
    description: "",
    type_id: 4,
    priority: 3,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_update_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Updated\",\"description\":null,\"type_id\":5,\"priority\":1}",
      decode.dynamic,
    )

  let assert Ok(payloads.UpdatePayload(
    name: Some("Updated"),
    description: None,
    type_id: Some(5),
    priority: Some(1),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_rejects_wrong_priority_type_test() {
  let assert Ok(dynamic) = json.parse("{\"priority\":\"high\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_update(dynamic)
}
