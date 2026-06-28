//// Shared API contracts for task leaf endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode

import domain/task/id as task_id
import domain/task/state.{
  type TaskClosedReason, ClosedByAncestor, ClosedByClaimant, ManuallyClosed,
}

pub type CloseTaskRequest {
  CloseTaskRequest(version: Int, reason: TaskClosedReason)
}

pub type CreateDependencyRequest {
  CreateDependencyRequest(depends_on_task_id: task_id.TaskId)
}

pub type DecodeError {
  InvalidJson
  InvalidClosedReason
}

fn create_dependency_request_codec() -> decode.Decoder(CreateDependencyRequest) {
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
    "done" -> Ok(ClosedByClaimant)
    "manually_closed" -> Ok(ManuallyClosed)
    "closed_by_ancestor" -> Ok(ClosedByAncestor)
    _ -> Error(InvalidClosedReason)
  }
}
