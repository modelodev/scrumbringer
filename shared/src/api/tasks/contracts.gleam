//// Shared API contracts for task leaf endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json.{type Json}

import domain/task/id as task_id
import domain/task/state.{
  type TaskClosedReason, type TaskExecutionState, Available, Claimed, Closed,
  ClosedByAncestor, Done, ManuallyClosed, Ongoing, Taken,
}

pub type CloseTaskRequest {
  CloseTaskRequest(version: Int, reason: TaskClosedReason)
}

pub type CreateDependencyRequest {
  CreateDependencyRequest(depends_on_task_id: task_id.TaskId)
}

pub type CloseTaskResponse {
  CloseTaskResponse(
    task_id: task_id.TaskId,
    execution_state: TaskExecutionState,
  )
}

pub type DecodeError {
  InvalidJson
  InvalidClosedReason
}

pub fn close_task_request_codec() -> decode.Decoder(CloseTaskRequest) {
  use version <- decode.field("version", decode.int)
  use reason <- decode.optional_field(
    "reason",
    "manually_closed",
    decode.string,
  )

  case parse_closed_reason(reason) {
    Ok(parsed_reason) ->
      decode.success(CloseTaskRequest(version: version, reason: parsed_reason))
    Error(_) ->
      decode.failure(
        CloseTaskRequest(version: version, reason: ManuallyClosed),
        "TaskClosedReason",
      )
  }
}

pub fn create_dependency_request_codec() -> decode.Decoder(
  CreateDependencyRequest,
) {
  use depends_on_task_id <- decode.field("depends_on_task_id", decode.int)
  decode.success(
    CreateDependencyRequest(depends_on_task_id: task_id.new(depends_on_task_id)),
  )
}

pub fn decode_close_task(data: Dynamic) -> Result(CloseTaskRequest, DecodeError) {
  case decode.run(data, close_task_raw_codec()) {
    Ok(#(version, reason)) ->
      case parse_closed_reason(reason) {
        Ok(parsed_reason) ->
          Ok(CloseTaskRequest(version: version, reason: parsed_reason))
        Error(error) -> Error(error)
      }
    Error(_) -> Error(InvalidJson)
  }
}

pub fn decode_create_dependency(
  data: Dynamic,
) -> Result(CreateDependencyRequest, DecodeError) {
  decode.run(data, create_dependency_request_codec())
  |> result_from_decode
}

pub fn close_task_response_to_json(response: CloseTaskResponse) -> Json {
  json.object([
    #("task_id", json.int(task_id.to_int(response.task_id))),
    #("execution_state", execution_state_to_json(response.execution_state)),
    #("closed_reason", closed_reason_for_response(response.execution_state)),
  ])
}

fn close_task_raw_codec() -> decode.Decoder(#(Int, String)) {
  use version <- decode.field("version", decode.int)
  use reason <- decode.optional_field(
    "reason",
    "manually_closed",
    decode.string,
  )
  decode.success(#(version, reason))
}

fn result_from_decode(result: Result(a, b)) -> Result(a, DecodeError) {
  case result {
    Ok(value) -> Ok(value)
    Error(_) -> Error(InvalidJson)
  }
}

fn parse_closed_reason(reason: String) -> Result(TaskClosedReason, DecodeError) {
  case reason {
    "done" -> Ok(Done)
    "manually_closed" -> Ok(ManuallyClosed)
    "closed_by_ancestor" -> Ok(ClosedByAncestor)
    _ -> Error(InvalidClosedReason)
  }
}

fn execution_state_to_json(state: TaskExecutionState) -> Json {
  case state {
    Available -> json.string("available")
    Claimed(_, _, Taken) -> json.string("claimed")
    Claimed(_, _, Ongoing) -> json.string("claimed")
    Closed(_, _, _) -> json.string("closed")
  }
}

fn closed_reason_for_response(state: TaskExecutionState) -> Json {
  case state {
    Closed(reason, _, _) -> closed_reason_to_json(reason)
    _ -> json.null()
  }
}

fn closed_reason_to_json(reason: TaskClosedReason) -> Json {
  case reason {
    Done -> json.string("done")
    ManuallyClosed -> json.string("manually_closed")
    ClosedByAncestor -> json.string("closed_by_ancestor")
  }
}
