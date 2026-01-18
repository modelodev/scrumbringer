//// Active task API functions.
////
//// ## Mission
////
//// Provides API operations for the user's active task (work tracking).
////
//// ## Responsibilities
////
//// - Get current user's active task
//// - Start/pause work on tasks
//// - Send heartbeats for active tasks
////
//// ## Relations
////
//// - **decoders.gleam**: Provides active task payload decoder
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/task.{type ActiveTaskPayload}
import scrumbringer_client/api/core
import scrumbringer_client/api/tasks/decoders

// =============================================================================
// Active Task API Functions
// =============================================================================

/// Get current user's active task.
pub fn get_me_active_task(
  to_msg: fn(core.ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/me/active-task",
    option.None,
    decoders.active_task_payload_decoder(),
    to_msg,
  )
}

/// Start working on a task.
pub fn start_me_active_task(
  task_id: Int,
  to_msg: fn(core.ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("task_id", json.int(task_id))])
  core.request(
    "POST",
    "/api/v1/me/active-task/start",
    option.Some(body),
    decoders.active_task_payload_decoder(),
    to_msg,
  )
}

/// Pause working on the active task.
pub fn pause_me_active_task(
  to_msg: fn(core.ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "POST",
    "/api/v1/me/active-task/pause",
    option.None,
    decoders.active_task_payload_decoder(),
    to_msg,
  )
}

/// Send heartbeat for active task.
pub fn heartbeat_me_active_task(
  to_msg: fn(core.ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "POST",
    "/api/v1/me/active-task/heartbeat",
    option.None,
    decoders.active_task_payload_decoder(),
    to_msg,
  )
}
