import gleam/dynamic/decode
import gleam/json

import scrumbringer_server/http/work_sessions/payloads

pub fn decode_task_id_payload_test() {
  let assert Ok(dynamic) = json.parse("{\"task_id\":123}", decode.dynamic)

  let assert Ok(payloads.TaskIdPayload(task_id: 123)) =
    payloads.decode_task_id(dynamic)
}

pub fn decode_task_id_payload_rejects_missing_task_id_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_task_id(dynamic)
}

pub fn decode_task_id_payload_rejects_non_int_task_id_test() {
  let assert Ok(dynamic) = json.parse("{\"task_id\":\"123\"}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_task_id(dynamic)
}
