import api/tasks/contracts.{
  CloseTaskRequest, CloseTaskResponse, CreateDependencyRequest,
}
import gleam/dynamic/decode
import gleam/json

import domain/task/id as task_id
import domain/task/state as task_state

const now = "2026-06-19T10:00:00Z"

pub fn close_task_api_contract_roundtrip_test() {
  let assert Ok(dynamic) =
    json.parse("{\"version\":3,\"reason\":\"manually_closed\"}", decode.dynamic)

  let assert Ok(request) = contracts.decode_close_task(dynamic)
  let assert CloseTaskRequest(version: 3, reason: task_state.ManuallyClosed) =
    request
}

pub fn task_dependencies_api_contract_roundtrip_test() {
  let assert Ok(dynamic) =
    json.parse("{\"depends_on_task_id\":42}", decode.dynamic)

  let assert Ok(request) = contracts.decode_create_dependency(dynamic)
  let CreateDependencyRequest(depends_on_task_id:) = request
  let assert True = depends_on_task_id == task_id.new(42)
}

pub fn close_task_response_uses_domain_execution_state_test() {
  let response =
    CloseTaskResponse(
      task_id: task_id.new(9),
      execution_state: task_state.Closed(
        reason: task_state.ManuallyClosed,
        closed_at: now,
        closed_by: 7,
      ),
    )
    |> contracts.close_task_response_to_json
    |> json.to_string

  let assert Ok("closed") =
    json.parse(response, string_field("execution_state"))
  let assert Ok("manually_closed") =
    json.parse(response, string_field("closed_reason"))
}

fn string_field(name: String) -> decode.Decoder(String) {
  use value <- decode.field(name, decode.string)
  decode.success(value)
}
