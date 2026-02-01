//// Task operations API functions.
////
//// ## Mission
////
//// Provides core task CRUD and workflow operations.
////
//// ## Responsibilities
////
//// - List tasks for a project
//// - Create new tasks
//// - Claim, release, and complete tasks
////
//// ## Relations
////
//// - **decoders.gleam**: Provides task decoder
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string

import lustre/effect.{type Effect}

import domain/task.{type Task, type TaskFilters, TaskFilters}
import scrumbringer_client/api/core
import scrumbringer_client/api/tasks/decoders
import scrumbringer_client/client_ffi

// =============================================================================
// URL Helpers
// =============================================================================

fn add_param_string(
  existing: String,
  key: String,
  value: option.Option(String),
) -> String {
  case value {
    option.None -> existing
    option.Some(v) ->
      existing
      <> append_query(existing)
      <> key
      <> "="
      <> client_ffi.encode_uri_component(v)
  }
}

fn add_param_int(
  existing: String,
  key: String,
  value: option.Option(Int),
) -> String {
  case value {
    option.None -> existing
    option.Some(v) ->
      existing <> append_query(existing) <> key <> "=" <> int.to_string(v)
  }
}

fn add_param_bool(
  existing: String,
  key: String,
  value: option.Option(Bool),
) -> String {
  case value {
    option.None -> existing
    option.Some(v) ->
      existing
      <> append_query(existing)
      <> key
      <> "="
      <> case v {
        True -> "true"
        False -> "false"
      }
  }
}

fn append_query(existing: String) -> String {
  case string.contains(existing, "?") {
    True -> "&"
    False -> "?"
  }
}

/// Build URL for project tasks with filters.
pub fn project_tasks_url(project_id: Int, filters: TaskFilters) -> String {
  let TaskFilters(
    status: status,
    type_id: type_id,
    capability_id: capability_id,
    q: q,
    blocked: blocked,
  ) = filters

  let params =
    ""
    |> add_param_string("status", status)
    |> add_param_int("type_id", type_id)
    |> add_param_int("capability_id", capability_id)
    |> add_param_string("q", q)
    |> add_param_bool("blocked", blocked)

  "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks" <> params
}

// =============================================================================
// Task List/Create API Functions
// =============================================================================

/// List tasks for a project with optional filters.
pub fn list_project_tasks(
  project_id: Int,
  filters: TaskFilters,
  to_msg: fn(core.ApiResult(List(Task))) -> msg,
) -> Effect(msg) {
  let url = project_tasks_url(project_id, filters)

  let decoder =
    decode.field("tasks", decode.list(decoders.task_decoder()), decode.success)

  core.request("GET", url, option.None, decoder, to_msg)
}

/// Create a new task in a project.
pub fn create_task(
  project_id: Int,
  title: String,
  description: option.Option(String),
  priority: Int,
  type_id: Int,
  to_msg: fn(core.ApiResult(Task)) -> msg,
) -> Effect(msg) {
  create_task_with_card(
    project_id,
    title,
    description,
    priority,
    type_id,
    option.None,
    to_msg,
  )
}

/// Create a new task in a project, optionally associated with a card.
pub fn create_task_with_card(
  project_id: Int,
  title: String,
  description: option.Option(String),
  priority: Int,
  type_id: Int,
  card_id: option.Option(Int),
  to_msg: fn(core.ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let entries = [
    #("title", json.string(title)),
    #("priority", json.int(priority)),
    #("type_id", json.int(type_id)),
  ]

  let entries = case description {
    option.Some(desc) ->
      list.append(entries, [#("description", json.string(desc))])
    option.None -> entries
  }

  let entries = case card_id {
    option.Some(cid) -> list.append(entries, [#("card_id", json.int(cid))])
    option.None -> entries
  }

  let body = json.object(entries)
  let decoder = decode.field("task", decoders.task_decoder(), decode.success)

  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// Task Workflow API Functions
// =============================================================================

/// Claim an available task.
pub fn claim_task(
  task_id: Int,
  version: Int,
  to_msg: fn(core.ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", decoders.task_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Release a claimed task back to available.
pub fn release_task(
  task_id: Int,
  version: Int,
  to_msg: fn(core.ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", decoders.task_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Complete a claimed task.
pub fn complete_task(
  task_id: Int,
  version: Int,
  to_msg: fn(core.ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", decoders.task_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
    option.Some(body),
    decoder,
    to_msg,
  )
}
