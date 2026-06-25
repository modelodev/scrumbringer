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
    trigger: automation.TaskClosed(Some(7)),
    action: automation.CreateTask(11),
    status: automation.Active,
  )) = payloads.decode_create(dynamic)
}

pub fn decode_create_payload_accepts_all_supported_triggers_test() {
  let assert Ok(payloads.CreatePayload(
    trigger: automation.TaskCreated(None),
    ..,
  )) =
    decode_create_trigger("{\"type\":\"task_created\",\"task_type_id\":null}")
  let assert Ok(payloads.CreatePayload(
    trigger: automation.TaskClaimed(Some(7)),
    ..,
  )) = decode_create_trigger("{\"type\":\"task_claimed\",\"task_type_id\":7}")
  let assert Ok(payloads.CreatePayload(
    trigger: automation.TaskReleased(None),
    ..,
  )) =
    decode_create_trigger("{\"type\":\"task_released\",\"task_type_id\":null}")
  let assert Ok(payloads.CreatePayload(
    trigger: automation.TaskClosed(Some(9)),
    ..,
  )) = decode_create_trigger("{\"type\":\"task_completed\",\"task_type_id\":9}")
  let assert Ok(payloads.CreatePayload(
    trigger: automation.CardActivated(automation.AnyCard),
    ..,
  )) =
    decode_create_trigger(
      "{\"type\":\"card_activated\",\"scope\":{\"type\":\"any_card\"}}",
    )
  let assert Ok(payloads.CreatePayload(
    trigger: automation.CardClosed(automation.AtDepth(depth)),
    ..,
  )) =
    decode_create_trigger(
      "{\"type\":\"card_closed\",\"scope\":{\"type\":\"at_depth\",\"depth\":2}}",
    )
  let assert 2 = automation.card_depth_to_int(depth)
}

pub fn decode_create_payload_rejects_parked_and_due_date_triggers_test() {
  let assert Error(Nil) =
    decode_create_trigger("{\"type\":\"task_blocked\",\"task_type_id\":null}")
  let assert Error(Nil) =
    decode_create_trigger("{\"type\":\"task_unblocked\",\"task_type_id\":null}")
  let assert Error(Nil) =
    decode_create_trigger("{\"type\":\"task_due_date_overdue\"}")
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

pub fn decode_update_payload_accepts_all_supported_triggers_test() {
  let assert Ok(payloads.UpdatePayload(
    trigger: Some(automation.TaskCreated(None)),
    ..,
  )) =
    decode_update_trigger("{\"type\":\"task_created\",\"task_type_id\":null}")
  let assert Ok(payloads.UpdatePayload(
    trigger: Some(automation.TaskClaimed(Some(7))),
    ..,
  )) = decode_update_trigger("{\"type\":\"task_claimed\",\"task_type_id\":7}")
  let assert Ok(payloads.UpdatePayload(
    trigger: Some(automation.TaskReleased(None)),
    ..,
  )) =
    decode_update_trigger("{\"type\":\"task_released\",\"task_type_id\":null}")
  let assert Ok(payloads.UpdatePayload(
    trigger: Some(automation.TaskClosed(Some(9))),
    ..,
  )) = decode_update_trigger("{\"type\":\"task_completed\",\"task_type_id\":9}")
  let assert Ok(payloads.UpdatePayload(
    trigger: Some(automation.CardActivated(automation.AnyCard)),
    ..,
  )) =
    decode_update_trigger(
      "{\"type\":\"card_activated\",\"scope\":{\"type\":\"any_card\"}}",
    )
  let assert Ok(payloads.UpdatePayload(
    trigger: Some(automation.CardClosed(automation.AtDepth(depth))),
    ..,
  )) =
    decode_update_trigger(
      "{\"type\":\"card_closed\",\"scope\":{\"type\":\"at_depth\",\"depth\":2}}",
    )
  let assert 2 = automation.card_depth_to_int(depth)
}

pub fn decode_update_payload_rejects_parked_and_due_date_triggers_test() {
  let assert Error(Nil) =
    decode_update_trigger("{\"type\":\"task_blocked\",\"task_type_id\":null}")
  let assert Error(Nil) =
    decode_update_trigger("{\"type\":\"task_unblocked\",\"task_type_id\":null}")
  let assert Error(Nil) =
    decode_update_trigger("{\"type\":\"task_due_date_overdue\"}")
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

fn decode_create_trigger(
  trigger_json: String,
) -> Result(payloads.CreatePayload, Nil) {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Rule\",\"trigger\":"
        <> trigger_json
        <> ",\"action\":{\"type\":\"create_task\",\"template_id\":11},\"status\":{\"type\":\"active\"}}",
      decode.dynamic,
    )

  payloads.decode_create(dynamic)
}

fn decode_update_trigger(
  trigger_json: String,
) -> Result(payloads.UpdatePayload, Nil) {
  let assert Ok(dynamic) =
    json.parse("{\"trigger\":" <> trigger_json <> "}", decode.dynamic)

  payloads.decode_update(dynamic)
}
