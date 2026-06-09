//// Task types API functions.
////
//// ## Mission
////
//// Provides API operations for task type management.
////
//// ## Responsibilities
////
//// - List task types for a project
//// - Create new task types
////
//// ## Relations
////
//// - **domain/task/codec.gleam**: Provides task type decoder
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/task/codec as decoders
import domain/task_type.{type TaskType}
import scrumbringer_client/api/core

// =============================================================================
// Task Type API Functions
// =============================================================================

/// List task types for a project.
pub fn list_task_types(
  project_id: Int,
  to_msg: fn(ApiResult(List(TaskType))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "task_types",
      decode.list(decoders.task_type_decoder()),
      decode.success,
    )
  core.request(
    core.Get,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    option.None,
    decoder,
    to_msg,
  )
}

/// Create a new task type for a project.
pub fn create_task_type(
  project_id: Int,
  name: String,
  icon: String,
  capability_id: option.Option(Int),
  to_msg: fn(ApiResult(TaskType)) -> msg,
) -> Effect(msg) {
  let base = [#("name", json.string(name)), #("icon", json.string(icon))]

  let entries = case capability_id {
    option.Some(id) -> list.append(base, [#("capability_id", json.int(id))])
    option.None -> base
  }

  let body = json.object(entries)
  let decoder =
    decode.field("task_type", decoders.task_type_decoder(), decode.success)

  core.request(
    core.Post,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Story 4.9 AC13: Update an existing task type.
pub fn update_task_type(
  type_id: Int,
  name: String,
  icon: String,
  capability_id: option.Option(Int),
  to_msg: fn(ApiResult(TaskType)) -> msg,
) -> Effect(msg) {
  let base = [#("name", json.string(name)), #("icon", json.string(icon))]

  let entries = case capability_id {
    option.Some(id) -> list.append(base, [#("capability_id", json.int(id))])
    option.None -> base
  }

  let body = json.object(entries)
  let decoder =
    decode.field("task_type", decoders.task_type_decoder(), decode.success)

  core.request(
    core.Patch,
    "/api/v1/task-types/" <> int.to_string(type_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Story 4.9 AC14: Delete a task type (only if no tasks use it).
pub fn delete_task_type(
  type_id: Int,
  to_msg: fn(ApiResult(Int)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("id", decode.int, decode.success)

  core.request(
    core.Delete,
    "/api/v1/task-types/" <> int.to_string(type_id),
    option.None,
    decoder,
    to_msg,
  )
}
