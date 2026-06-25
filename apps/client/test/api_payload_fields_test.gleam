//// Tests for shared API payload field encoders.

import gleam/json
import scrumbringer_client/api/payload_fields

pub fn active_update_field_encodes_true_as_numeric_one_test() {
  let assert "{\"active\":1}" =
    json.object([payload_fields.active_update_field(True)])
    |> json.to_string()
}

pub fn active_update_field_encodes_false_as_numeric_zero_test() {
  let assert "{\"active\":0}" =
    json.object([payload_fields.active_update_field(False)])
    |> json.to_string()
}
