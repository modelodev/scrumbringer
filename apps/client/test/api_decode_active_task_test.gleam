import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleeunit/should
import scrumbringer_client/api

pub fn active_task_payload_decoder_decodes_active_task_test() {
  let body =
    "{\"data\":{\"active_task\":{\"task_id\":1,\"project_id\":10,\"started_at\":\"2026-01-15T10:00:00Z\"},\"as_of\":\"2026-01-15T10:00:05Z\"}}"

  let decoder =
    decode.field("data", api.active_task_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result
  |> should.be_ok
  |> should.equal(api.ActiveTaskPayload(
    active_task: option.Some(api.ActiveTask(
      task_id: 1,
      project_id: 10,
      started_at: "2026-01-15T10:00:00Z",
    )),
    as_of: "2026-01-15T10:00:05Z",
  ))
}

pub fn active_task_payload_decoder_decodes_null_active_task_test() {
  let body =
    "{\"data\":{\"active_task\":null,\"as_of\":\"2026-01-15T10:00:05Z\"}}"

  let decoder =
    decode.field("data", api.active_task_payload_decoder(), decode.success)

  json.parse(from: body, using: decoder)
  |> should.be_ok
  |> should.equal(api.ActiveTaskPayload(
    active_task: option.None,
    as_of: "2026-01-15T10:00:05Z",
  ))
}
