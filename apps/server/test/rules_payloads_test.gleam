import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import scrumbringer_server/http/rules/payloads

pub fn decode_create_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Rule\",\"goal\":\"Ship\",\"resource_type\":\"task\",\"task_type_id\":7,\"to_state\":\"completed\",\"template_id\":11,\"active\":true}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreatePayload(
    name: "Rule",
    goal: "Ship",
    resource_type: "task",
    task_type_id: Some(7),
    to_state: "completed",
    template_id: Some(11),
    active: True,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_create_payload_defaults_optional_fields_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Rule\",\"resource_type\":\"card\",\"to_state\":\"cerrada\"}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreatePayload(
    name: "Rule",
    goal: "",
    resource_type: "card",
    task_type_id: None,
    to_state: "cerrada",
    template_id: None,
    active: False,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_update_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Updated\",\"goal\":null,\"resource_type\":\"task\",\"task_type_id\":9,\"to_state\":\"claimed\",\"template_id\":12,\"active\":1}",
      decode.dynamic,
    )

  let assert Ok(payloads.UpdatePayload(
    name: Some("Updated"),
    goal: None,
    resource_type: Some("task"),
    task_type_id: Some(9),
    to_state: Some("claimed"),
    template_id: Some(12),
    active: Some(True),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_decodes_inactive_flag_test() {
  let assert Ok(dynamic) = json.parse("{\"active\":0}", decode.dynamic)

  let assert Ok(payloads.UpdatePayload(
    name: None,
    goal: None,
    resource_type: None,
    task_type_id: None,
    to_state: None,
    template_id: None,
    active: Some(False),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_rejects_unknown_active_flag_test() {
  let assert Ok(dynamic) = json.parse("{\"active\":2}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_update(dynamic)
}

pub fn decode_execution_order_defaults_to_zero_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Ok(0) = payloads.decode_execution_order(dynamic)
}

pub fn decode_execution_order_rejects_wrong_type_test() {
  let assert Ok(dynamic) =
    json.parse("{\"execution_order\":\"first\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_execution_order(dynamic)
}
