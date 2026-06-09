import domain/field_update
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import scrumbringer_server/http/tasks/payloads

pub fn decode_create_task_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"title\":\"Task\",\"description\":\"Desc\",\"priority\":2,\"type_id\":3,\"card_id\":4}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreateTaskPayload(
    title: "Task",
    description: "Desc",
    priority: 2,
    type_id: 3,
    card_id: Some(4),
    milestone_id: None,
  )) = payloads.decode_create_task(dynamic)
}

pub fn decode_create_task_payload_defaults_description_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"title\":\"Task\",\"priority\":1,\"type_id\":2}",
      decode.dynamic,
    )

  let assert Ok(payloads.CreateTaskPayload(description: "", ..)) =
    payloads.decode_create_task(dynamic)
}

pub fn decode_create_task_payload_rejects_missing_priority_test() {
  let assert Ok(dynamic) =
    json.parse("{\"title\":\"Task\",\"type_id\":2}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_create_task(dynamic)
}

pub fn decode_update_task_payload_sets_milestone_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"version\":3,\"title\":\"New\",\"milestone_id\":7}",
      decode.dynamic,
    )

  let assert Ok(payloads.UpdateTaskPayload(version: 3, updates: updates)) =
    payloads.decode_update_task(dynamic)
  let assert field_update.Set(Some(7)) = updates.milestone_id
}

pub fn decode_update_task_payload_normalizes_non_positive_milestone_test() {
  let assert Ok(dynamic) =
    json.parse("{\"version\":3,\"milestone_id\":0}", decode.dynamic)

  let assert Ok(payloads.UpdateTaskPayload(updates: updates, ..)) =
    payloads.decode_update_task(dynamic)
  let assert field_update.Set(None) = updates.milestone_id
}

pub fn decode_update_task_payload_leaves_absent_milestone_unchanged_test() {
  let assert Ok(dynamic) = json.parse("{\"version\":3}", decode.dynamic)

  let assert Ok(payloads.UpdateTaskPayload(updates: updates, ..)) =
    payloads.decode_update_task(dynamic)
  let assert field_update.Unchanged = updates.milestone_id
}

pub fn decode_update_task_payload_rejects_invalid_milestone_test() {
  let assert Ok(dynamic) =
    json.parse("{\"version\":3,\"milestone_id\":\"later\"}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_update_task(dynamic)
}

pub fn decode_version_payload_test() {
  let assert Ok(dynamic) = json.parse("{\"version\":9}", decode.dynamic)

  let assert Ok(payloads.VersionPayload(version: 9)) =
    payloads.decode_version(dynamic)
}

pub fn decode_dependency_payload_test() {
  let assert Ok(dynamic) =
    json.parse("{\"depends_on_task_id\":11}", decode.dynamic)

  let assert Ok(payloads.DependencyPayload(depends_on_task_id: 11)) =
    payloads.decode_dependency(dynamic)
}

pub fn decode_task_type_payload_maps_zero_capability_to_none_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Bug\",\"icon\":\"bug\",\"capability_id\":0}",
      decode.dynamic,
    )

  let assert Ok(payloads.TaskTypePayload(
    name: "Bug",
    icon: "bug",
    capability_id: None,
  )) = payloads.decode_task_type(dynamic)
}

pub fn decode_task_type_payload_accepts_capability_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Bug\",\"icon\":\"bug\",\"capability_id\":5}",
      decode.dynamic,
    )

  let assert Ok(payloads.TaskTypePayload(capability_id: Some(5), ..)) =
    payloads.decode_task_type(dynamic)
}
