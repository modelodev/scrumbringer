import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import domain/automation
import scrumbringer_server/http/rules/payloads

pub fn decode_create_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Rule\",\"goal\":\"Ship\",\"trigger\":{\"type\":\"task_completed\",\"task_type_id\":7},\"action\":{\"type\":\"create_task\",\"template_id\":11},\"status\":{\"type\":\"active\"}}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreatePayload(
    name: "Rule",
    goal: "Ship",
    trigger: automation.TaskCompleted(Some(7)),
    action: automation.CreateTask(11),
    status: automation.Active,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_create_payload_requires_template_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Rule\",\"trigger\":{\"type\":\"card_closed\",\"scope\":{\"type\":\"any_card\"}}}",
      decode.dynamic,
    )

  let assert Error(Nil) = payloads.decode_create(dynamic)
}

pub fn decode_update_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Updated\",\"goal\":null,\"trigger\":{\"type\":\"task_claimed\",\"task_type_id\":9},\"action\":{\"type\":\"create_task\",\"template_id\":12},\"status\":{\"type\":\"active\"}}",
      decode.dynamic,
    )

  let assert Ok(payloads.UpdatePayload(
    name: Some("Updated"),
    goal: None,
    trigger: Some(automation.TaskClaimed(Some(9))),
    action: Some(automation.CreateTask(12)),
    status: Some(automation.Active),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_decodes_paused_status_test() {
  let assert Ok(dynamic) =
    json.parse("{\"status\":{\"type\":\"paused\"}}", decode.dynamic)

  let assert Ok(payloads.UpdatePayload(
    name: None,
    goal: None,
    trigger: None,
    action: None,
    status: Some(automation.Paused),
  )) = payloads.decode_update(dynamic)
}

pub fn decode_update_payload_rejects_unknown_status_test() {
  let assert Ok(dynamic) =
    json.parse("{\"status\":{\"type\":\"archived\"}}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_update(dynamic)
}
