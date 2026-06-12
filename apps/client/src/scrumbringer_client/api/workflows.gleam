//// Workflow API functions for Scrumbringer client.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{None, Some}

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/workflow.{type Workflow}
import domain/workflow/codec as workflow_codec
import scrumbringer_client/api/core

/// Decoder for workflow wrapped in envelope.
pub fn workflow_payload_decoder() -> decode.Decoder(Workflow) {
  decode.field("workflow", workflow_codec.workflow_decoder(), decode.success)
}

/// Decoder for list of workflows.
pub fn workflows_payload_decoder() -> decode.Decoder(List(Workflow)) {
  decode.field(
    "workflows",
    decode.list(workflow_codec.workflow_decoder()),
    decode.success,
  )
}

/// List workflows for a project.
pub fn list_project_workflows(
  project_id: Int,
  to_msg: fn(ApiResult(List(Workflow))) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
    None,
    workflows_payload_decoder(),
    to_msg,
  )
}

/// Create workflow in a project.
pub fn create_project_workflow(
  project_id: Int,
  name: String,
  description: String,
  active: Bool,
  to_msg: fn(ApiResult(Workflow)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("active", json.bool(active)),
    ])
  core.request(
    core.Post,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
    Some(body),
    workflow_payload_decoder(),
    to_msg,
  )
}

/// Update workflow.
pub fn update_workflow(
  workflow_id: Int,
  name: String,
  description: String,
  active: Bool,
  to_msg: fn(ApiResult(Workflow)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #(
        "active",
        json.int(case active {
          True -> 1
          False -> 0
        }),
      ),
    ])
  core.request(
    core.Patch,
    "/api/v1/workflows/" <> int.to_string(workflow_id),
    Some(body),
    workflow_payload_decoder(),
    to_msg,
  )
}

/// Delete workflow.
pub fn delete_workflow(
  workflow_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/workflows/" <> int.to_string(workflow_id),
    None,
    to_msg,
  )
}
