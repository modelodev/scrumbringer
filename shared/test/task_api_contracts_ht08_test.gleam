import api/tasks/contracts.{CloseTaskRequest, CreateDependencyRequest}
import gleam/dynamic/decode
import gleam/json

import domain/task/id as task_id
import domain/task/state as task_state

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
