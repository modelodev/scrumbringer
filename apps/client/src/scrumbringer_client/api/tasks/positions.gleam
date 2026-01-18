//// Task positions API functions.
////
//// ## Mission
////
//// Provides API operations for user's task board positions.
////
//// ## Responsibilities
////
//// - List user's task positions
//// - Update/create task positions
////
//// ## Relations
////
//// - **decoders.gleam**: Provides position decoder
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/task.{type TaskPosition}
import scrumbringer_client/api/core
import scrumbringer_client/api/tasks/decoders

// =============================================================================
// Task Position API Functions
// =============================================================================

/// List user's task positions, optionally filtered by project.
pub fn list_me_task_positions(
  project_id: option.Option(Int),
  to_msg: fn(core.ApiResult(List(TaskPosition))) -> msg,
) -> Effect(msg) {
  let url = case project_id {
    option.None -> "/api/v1/me/task-positions"
    option.Some(id) ->
      "/api/v1/me/task-positions?project_id=" <> int.to_string(id)
  }

  let decoder =
    decode.field(
      "positions",
      decode.list(decoders.position_decoder()),
      decode.success,
    )

  core.request("GET", url, option.None, decoder, to_msg)
}

/// Update or create a task position.
pub fn upsert_me_task_position(
  task_id: Int,
  x: Int,
  y: Int,
  to_msg: fn(core.ApiResult(TaskPosition)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("x", json.int(x)), #("y", json.int(y))])
  let decoder =
    decode.field("position", decoders.position_decoder(), decode.success)

  core.request(
    "PUT",
    "/api/v1/me/task-positions/" <> int.to_string(task_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}
