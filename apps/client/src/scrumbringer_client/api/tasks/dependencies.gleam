////
//// Task dependency API operations.
////

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/task.{type TaskDependency}
import scrumbringer_client/api/core
import scrumbringer_client/api/tasks/decoders

pub fn list_task_dependencies(
  task_id: Int,
  to_msg: fn(core.ApiResult(List(TaskDependency))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "dependencies",
      decode.list(decoders.task_dependency_decoder()),
      decode.success,
    )

  core.request(
    "GET",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/dependencies",
    option.None,
    decoder,
    to_msg,
  )
}

pub fn add_task_dependency(
  task_id: Int,
  depends_on_task_id: Int,
  to_msg: fn(core.ApiResult(TaskDependency)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([#("depends_on_task_id", json.int(depends_on_task_id))])
  let decoder =
    decode.field(
      "dependency",
      decoders.task_dependency_decoder(),
      decode.success,
    )

  core.request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/dependencies",
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn delete_task_dependency(
  task_id: Int,
  depends_on_task_id: Int,
  to_msg: fn(core.ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/tasks/"
      <> int.to_string(task_id)
      <> "/dependencies/"
      <> int.to_string(depends_on_task_id),
    option.None,
    to_msg,
  )
}
