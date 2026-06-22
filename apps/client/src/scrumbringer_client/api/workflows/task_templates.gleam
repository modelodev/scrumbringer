//// Task template API functions for automation workflows.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{None, Some}

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/workflow.{type TaskTemplate}
import domain/workflow/workflow_codec
import scrumbringer_client/api/core

/// Decoder for task template wrapped in envelope.
pub fn task_template_payload_decoder() -> decode.Decoder(TaskTemplate) {
  decode.field(
    "template",
    workflow_codec.task_template_decoder(),
    decode.success,
  )
}

/// Decoder for list of task templates.
pub fn task_templates_payload_decoder() -> decode.Decoder(List(TaskTemplate)) {
  decode.field(
    "templates",
    decode.list(workflow_codec.task_template_decoder()),
    decode.success,
  )
}

/// List task templates for a project.
pub fn list_project_templates(
  project_id: Int,
  to_msg: fn(ApiResult(List(TaskTemplate))) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
    None,
    task_templates_payload_decoder(),
    to_msg,
  )
}

/// Create task template in a project.
pub fn create_project_template(
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  to_msg: fn(ApiResult(TaskTemplate)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("type_id", json.int(type_id)),
      #("priority", json.int(priority)),
    ])
  core.request(
    core.Post,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
    Some(body),
    task_template_payload_decoder(),
    to_msg,
  )
}

/// Update task template.
pub fn update_template(
  template_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  to_msg: fn(ApiResult(TaskTemplate)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("type_id", json.int(type_id)),
      #("priority", json.int(priority)),
    ])
  core.request(
    core.Patch,
    "/api/v1/task-templates/" <> int.to_string(template_id),
    Some(body),
    task_template_payload_decoder(),
    to_msg,
  )
}

/// Delete task template.
pub fn delete_template(
  template_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/task-templates/" <> int.to_string(template_id),
    None,
    to_msg,
  )
}
