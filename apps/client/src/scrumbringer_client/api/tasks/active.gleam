//// Active task / work sessions API functions.
////
//// ## Mission
////
//// Provides API operations for the user's work sessions (time tracking).
//// Supports multiple concurrent work sessions per user.
////
//// ## Responsibilities
////
//// - Get current user's active work sessions
//// - Start/pause work on tasks
//// - Send heartbeats for active sessions
////
//// ## Relations
////
//// - **decoders.gleam**: Provides work sessions payload decoder
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/task.{type WorkSessionsPayload}
import scrumbringer_client/api/core
import scrumbringer_client/api/tasks/decoders

// =============================================================================
// Work Sessions API Functions
// =============================================================================

/// Get current user's active work sessions.
pub fn get_work_sessions(
  to_msg: fn(core.ApiResult(WorkSessionsPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/me/work-sessions/active",
    option.None,
    decoders.work_sessions_payload_decoder(),
    to_msg,
  )
}

/// Start working on a task.
pub fn start_work_session(
  task_id: Int,
  to_msg: fn(core.ApiResult(WorkSessionsPayload)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("task_id", json.int(task_id))])
  core.request(
    "POST",
    "/api/v1/me/work-sessions/start",
    option.Some(body),
    decoders.work_sessions_payload_decoder(),
    to_msg,
  )
}

/// Pause working on a task.
pub fn pause_work_session(
  task_id: Int,
  to_msg: fn(core.ApiResult(WorkSessionsPayload)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("task_id", json.int(task_id))])
  core.request(
    "POST",
    "/api/v1/me/work-sessions/pause",
    option.Some(body),
    decoders.work_sessions_payload_decoder(),
    to_msg,
  )
}

/// Send heartbeat for a specific task session.
pub fn heartbeat_work_session(
  task_id: Int,
  to_msg: fn(core.ApiResult(WorkSessionsPayload)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("task_id", json.int(task_id))])
  core.request(
    "POST",
    "/api/v1/me/work-sessions/heartbeat",
    option.Some(body),
    decoders.work_sessions_payload_decoder(),
    to_msg,
  )
}
