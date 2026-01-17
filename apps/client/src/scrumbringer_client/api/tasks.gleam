//// Tasks API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides task management API operations including listing, creating,
//// claiming, releasing, completing tasks, and managing task positions.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/tasks
////
//// tasks.list_project_tasks(project_id, filters, TasksFetched)
//// tasks.claim_task(task_id, version, TaskClaimed)
//// tasks.complete_task(task_id, version, TaskCompleted)
//// ```

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/client_ffi

// =============================================================================
// Types
// =============================================================================

/// A task type definition.
pub type TaskType {
  TaskType(
    id: Int,
    name: String,
    icon: String,
    capability_id: option.Option(Int),
  )
}

/// Inline task type info embedded in a task.
pub type TaskTypeInline {
  TaskTypeInline(id: Int, name: String, icon: String)
}

/// Task status with claimed state variants.
/// Makes invalid states unrepresentable:
/// - Ongoing implies Claimed
/// - Available/Completed are mutually exclusive with Claimed
pub type TaskStatus {
  Available
  Claimed(ClaimedState)
  Completed
}

/// State of a claimed task.
pub type ClaimedState {
  Taken
  Ongoing
}

/// Work state for UI display.
pub type WorkState {
  WorkAvailable
  WorkClaimed
  WorkOngoing
  WorkCompleted
}

/// User currently working on a task.
pub type OngoingBy {
  OngoingBy(user_id: Int)
}

/// A task in a project.
pub type Task {
  Task(
    id: Int,
    project_id: Int,
    type_id: Int,
    task_type: TaskTypeInline,
    ongoing_by: option.Option(OngoingBy),
    title: String,
    description: option.Option(String),
    priority: Int,
    status: TaskStatus,
    work_state: WorkState,
    created_by: Int,
    claimed_by: option.Option(Int),
    claimed_at: option.Option(String),
    completed_at: option.Option(String),
    created_at: String,
    version: Int,
  )
}

/// A note on a task.
pub type TaskNote {
  TaskNote(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
}

/// Position of a task in the user's pool view.
pub type TaskPosition {
  TaskPosition(task_id: Int, user_id: Int, x: Int, y: Int, updated_at: String)
}

/// Currently active task for a user.
pub type ActiveTask {
  ActiveTask(
    task_id: Int,
    project_id: Int,
    started_at: String,
    accumulated_s: Int,
  )
}

/// Payload containing active task and server timestamp.
pub type ActiveTaskPayload {
  ActiveTaskPayload(active_task: option.Option(ActiveTask), as_of: String)
}

/// Filters for listing tasks.
pub type TaskFilters {
  TaskFilters(
    status: option.Option(String),
    type_id: option.Option(Int),
    capability_id: option.Option(Int),
    q: option.Option(String),
  )
}

// =============================================================================
// Status Parsing
// =============================================================================

/// Parse a task status string into TaskStatus.
pub fn parse_task_status(value: String) -> Result(TaskStatus, String) {
  case value {
    "available" -> Ok(Available)
    "claimed" -> Ok(Claimed(Taken))
    "ongoing" -> Ok(Claimed(Ongoing))
    "completed" -> Ok(Completed)
    _ -> Error("Unknown task status: " <> value)
  }
}

/// Convert TaskStatus to string for API.
pub fn task_status_to_string(status: TaskStatus) -> String {
  case status {
    Available -> "available"
    Claimed(Taken) -> "claimed"
    Claimed(Ongoing) -> "ongoing"
    Completed -> "completed"
  }
}

// =============================================================================
// Decoders
// =============================================================================

fn task_type_decoder() -> decode.Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)

  use capability_id <- decode.optional_field(
    "capability_id",
    option.None,
    decode.optional(decode.int),
  )

  decode.success(TaskType(
    id: id,
    name: name,
    icon: icon,
    capability_id: capability_id,
  ))
}

fn task_type_inline_decoder() -> decode.Decoder(TaskTypeInline) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  decode.success(TaskTypeInline(id: id, name: name, icon: icon))
}

fn ongoing_by_decoder() -> decode.Decoder(OngoingBy) {
  use user_id <- decode.field("user_id", decode.int)
  decode.success(OngoingBy(user_id: user_id))
}

fn work_state_decoder() -> decode.Decoder(WorkState) {
  decode.string
  |> decode.map(fn(raw) {
    case raw {
      "available" -> WorkAvailable
      "claimed" -> WorkClaimed
      "ongoing" -> WorkOngoing
      "completed" -> WorkCompleted
      _ -> WorkClaimed
    }
  })
}

/// Decoder for Task type.
pub fn task_decoder() -> decode.Decoder(Task) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use type_id <- decode.field("type_id", decode.int)

  use task_type <- decode.field("task_type", task_type_inline_decoder())

  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(ongoing_by_decoder()),
  )

  use title <- decode.field("title", decode.string)

  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )

  use priority <- decode.field("priority", decode.int)

  use status_raw <- decode.field("status", decode.string)
  let status = case parse_task_status(status_raw) {
    Ok(s) -> s
    Error(_) -> Available
  }

  use work_state <- decode.field("work_state", work_state_decoder())

  use created_by <- decode.field("created_by", decode.int)

  use claimed_by <- decode.optional_field(
    "claimed_by",
    option.None,
    decode.optional(decode.int),
  )

  use claimed_at <- decode.optional_field(
    "claimed_at",
    option.None,
    decode.optional(decode.string),
  )

  use completed_at <- decode.optional_field(
    "completed_at",
    option.None,
    decode.optional(decode.string),
  )

  use created_at <- decode.field("created_at", decode.string)
  use version <- decode.field("version", decode.int)

  decode.success(Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    task_type: task_type,
    ongoing_by: ongoing_by,
    title: title,
    description: description,
    priority: priority,
    status: status,
    work_state: work_state,
    created_by: created_by,
    claimed_by: claimed_by,
    claimed_at: claimed_at,
    completed_at: completed_at,
    created_at: created_at,
    version: version,
  ))
}

fn note_decoder() -> decode.Decoder(TaskNote) {
  use id <- decode.field("id", decode.int)
  use task_id <- decode.field("task_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use content <- decode.field("content", decode.string)
  use created_at <- decode.field("created_at", decode.string)

  decode.success(TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
  ))
}

fn position_decoder() -> decode.Decoder(TaskPosition) {
  use task_id <- decode.field("task_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use x <- decode.field("x", decode.int)
  use y <- decode.field("y", decode.int)
  use updated_at <- decode.field("updated_at", decode.string)

  decode.success(TaskPosition(
    task_id: task_id,
    user_id: user_id,
    x: x,
    y: y,
    updated_at: updated_at,
  ))
}

fn active_task_decoder() -> decode.Decoder(ActiveTask) {
  use task_id <- decode.field("task_id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use started_at <- decode.field("started_at", decode.string)
  use accumulated <- decode.optional_field(
    "accumulated_s",
    option.None,
    decode.optional(decode.int),
  )

  let accumulated_s = case accumulated {
    option.Some(v) -> v
    option.None -> 0
  }

  decode.success(ActiveTask(
    task_id: task_id,
    project_id: project_id,
    started_at: started_at,
    accumulated_s: accumulated_s,
  ))
}

/// Decoder for active task payload.
pub fn active_task_payload_decoder() -> decode.Decoder(ActiveTaskPayload) {
  use active_task <- decode.field(
    "active_task",
    decode.optional(active_task_decoder()),
  )
  use as_of <- decode.field("as_of", decode.string)
  decode.success(ActiveTaskPayload(active_task: active_task, as_of: as_of))
}

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
  ) = filters

  let params =
    ""
    |> add_param_string("status", status)
    |> add_param_int("type_id", type_id)
    |> add_param_int("capability_id", capability_id)
    |> add_param_string("q", q)

  "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks" <> params
}

// =============================================================================
// Task Type API Functions
// =============================================================================

/// List task types for a project.
pub fn list_task_types(
  project_id: Int,
  to_msg: fn(ApiResult(List(TaskType))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("task_types", decode.list(task_type_decoder()), decode.success)
  core.request(
    "GET",
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
  let decoder = decode.field("task_type", task_type_decoder(), decode.success)

  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// Task API Functions
// =============================================================================

/// List tasks for a project with optional filters.
pub fn list_project_tasks(
  project_id: Int,
  filters: TaskFilters,
  to_msg: fn(ApiResult(List(Task))) -> msg,
) -> Effect(msg) {
  let url = project_tasks_url(project_id, filters)

  let decoder =
    decode.field("tasks", decode.list(task_decoder()), decode.success)

  core.request("GET", url, option.None, decoder, to_msg)
}

/// Create a new task in a project.
pub fn create_task(
  project_id: Int,
  title: String,
  description: option.Option(String),
  priority: Int,
  type_id: Int,
  to_msg: fn(ApiResult(Task)) -> msg,
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

  let body = json.object(entries)
  let decoder = decode.field("task", task_decoder(), decode.success)

  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Claim an available task.
pub fn claim_task(
  task_id: Int,
  version: Int,
  to_msg: fn(ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", task_decoder(), decode.success)
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
  to_msg: fn(ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", task_decoder(), decode.success)
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
  to_msg: fn(ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", task_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// Task Notes API Functions
// =============================================================================

/// List notes for a task.
pub fn list_task_notes(
  task_id: Int,
  to_msg: fn(ApiResult(List(TaskNote))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("notes", decode.list(note_decoder()), decode.success)
  core.request(
    "GET",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    option.None,
    decoder,
    to_msg,
  )
}

/// Add a note to a task.
pub fn add_task_note(
  task_id: Int,
  content: String,
  to_msg: fn(ApiResult(TaskNote)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("content", json.string(content))])
  let decoder = decode.field("note", note_decoder(), decode.success)

  core.request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// Active Task API Functions
// =============================================================================

/// Get current user's active task.
pub fn get_me_active_task(
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/me/active-task",
    option.None,
    active_task_payload_decoder(),
    to_msg,
  )
}

/// Start working on a task.
pub fn start_me_active_task(
  task_id: Int,
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("task_id", json.int(task_id))])
  core.request(
    "POST",
    "/api/v1/me/active-task/start",
    option.Some(body),
    active_task_payload_decoder(),
    to_msg,
  )
}

/// Pause working on the active task.
pub fn pause_me_active_task(
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "POST",
    "/api/v1/me/active-task/pause",
    option.None,
    active_task_payload_decoder(),
    to_msg,
  )
}

/// Send heartbeat for active task.
pub fn heartbeat_me_active_task(
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "POST",
    "/api/v1/me/active-task/heartbeat",
    option.None,
    active_task_payload_decoder(),
    to_msg,
  )
}

// =============================================================================
// Task Position API Functions
// =============================================================================

/// List user's task positions, optionally filtered by project.
pub fn list_me_task_positions(
  project_id: option.Option(Int),
  to_msg: fn(ApiResult(List(TaskPosition))) -> msg,
) -> Effect(msg) {
  let url = case project_id {
    option.None -> "/api/v1/me/task-positions"
    option.Some(id) ->
      "/api/v1/me/task-positions?project_id=" <> int.to_string(id)
  }

  let decoder =
    decode.field("positions", decode.list(position_decoder()), decode.success)

  core.request("GET", url, option.None, decoder, to_msg)
}

/// Update or create a task position.
pub fn upsert_me_task_position(
  task_id: Int,
  x: Int,
  y: Int,
  to_msg: fn(ApiResult(TaskPosition)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("x", json.int(x)), #("y", json.int(y))])
  let decoder = decode.field("position", position_decoder(), decode.success)

  core.request(
    "PUT",
    "/api/v1/me/task-positions/" <> int.to_string(task_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// User Capability API Functions
// =============================================================================

/// Get current user's capability IDs.
pub fn get_me_capability_ids(
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  core.request("GET", "/api/v1/me/capabilities", option.None, decoder, to_msg)
}

/// Update current user's capability IDs.
pub fn put_me_capability_ids(
  ids: List(Int),
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let body = json.object([#("capability_ids", json.array(ids, of: json.int))])
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  core.request("PUT", "/api/v1/me/capabilities", option.Some(body), decoder, to_msg)
}
