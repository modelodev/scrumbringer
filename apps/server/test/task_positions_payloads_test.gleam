import gleam/dynamic/decode
import gleam/json

import scrumbringer_server/http/task_positions/payloads

pub fn decode_position_payload_test() {
  let assert Ok(dynamic) = json.parse("{\"x\":4,\"y\":7}", decode.dynamic)

  let assert Ok(payloads.PositionPayload(x: 4, y: 7)) =
    payloads.decode_position(dynamic)
}

pub fn decode_position_payload_rejects_missing_y_test() {
  let assert Ok(dynamic) = json.parse("{\"x\":4}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_position(dynamic)
}

pub fn parse_project_id_filter_defaults_to_zero_test() {
  let assert Ok(0) = payloads.parse_project_id_filter([])
}

pub fn parse_project_id_filter_accepts_single_value_test() {
  let assert Ok(42) = payloads.parse_project_id_filter([#("project_id", "42")])
}

pub fn parse_project_id_filter_rejects_invalid_value_test() {
  let assert Error(payloads.InvalidProjectId) =
    payloads.parse_project_id_filter([#("project_id", "abc")])
}

pub fn parse_project_id_filter_rejects_duplicate_values_test() {
  let assert Error(payloads.InvalidProjectId) =
    payloads.parse_project_id_filter([
      #("project_id", "1"),
      #("project_id", "2"),
    ])
}
