//// HTTP handlers for work sessions (multi-session time tracking).
////
//// ## Mission
////
//// Handle HTTP requests for work session operations.
////
//// ## Responsibilities
////
//// - HTTP method validation
//// - Authentication checks
//// - Request body parsing
//// - CSRF validation
//// - Response JSON construction
////
//// ## Endpoints
////
//// - GET  /api/v1/me/work-sessions/active
//// - POST /api/v1/me/work-sessions/start
//// - POST /api/v1/me/work-sessions/pause
//// - POST /api/v1/me/work-sessions/heartbeat

import gleam/http
import gleam/int
import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/work_sessions/payloads as session_payloads
import scrumbringer_server/http/work_sessions/presenters as session_presenters
import scrumbringer_server/use_case/rate_limit
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/time
import scrumbringer_server/use_case/work_sessions_db
import wisp

const heartbeat_rate_limit_window_seconds = 30

const heartbeat_rate_limit_limit = 1

fn heartbeat_rate_limit_ok(user_id: Int, task_id: Int) -> Bool {
  rate_limit.allow(
    "work_sessions_heartbeat:"
      <> int.to_string(user_id)
      <> ":"
      <> int.to_string(task_id),
    heartbeat_rate_limit_limit,
    heartbeat_rate_limit_window_seconds,
    time.now_unix_seconds(),
  )
}

fn work_session_internal_error_response(
  error: work_sessions_db.WorkSessionError,
) -> wisp.Response {
  case error {
    work_sessions_db.DbError(_) -> api.error(500, "INTERNAL", "Database error")
    work_sessions_db.NotClaimed
    | work_sessions_db.TaskDone
    | work_sessions_db.SessionNotFound ->
      api.error(500, "INTERNAL", "Unexpected error")
  }
}

// =============================================================================
// Public Handlers
// =============================================================================

/// Handle GET /api/v1/me/work-sessions/active.
///
/// Example:
///   handle_get_active(req, ctx)
pub fn handle_get_active(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> get_active_for_user(ctx, user)
  }
}

/// Handle POST /api/v1/me/work-sessions/start.
///
/// Example:
///   handle_start(req, ctx)
pub fn handle_start(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> start_for_user(req, ctx, user)
  }
}

/// Handle POST /api/v1/me/work-sessions/pause.
///
/// Example:
///   handle_pause(req, ctx)
pub fn handle_pause(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> pause_for_user(req, ctx, user)
  }
}

/// Handle POST /api/v1/me/work-sessions/heartbeat.
///
/// Example:
///   handle_heartbeat(req, ctx)
pub fn handle_heartbeat(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> heartbeat_for_user(req, ctx, user)
  }
}

// =============================================================================
// Handler Helpers
// =============================================================================

fn get_active_for_user(ctx: auth.Ctx, user: StoredUser) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Lazy cleanup: close stale sessions before returning active list.
  let _ = work_sessions_db.close_stale_sessions(db)

  case work_sessions_db.get_active_sessions(db, user.id) {
    Ok(state) -> api.ok(session_presenters.state(state))
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn start_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  with_task_id_mutation(req, fn(payload) { start_session(ctx, user, payload) })
}

fn start_session(
  ctx: auth.Ctx,
  user: StoredUser,
  payload: session_payloads.TaskIdPayload,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case work_sessions_db.start_session(db, user.id, payload.task_id) {
    Ok(state) -> api.ok(session_presenters.state(state))

    Error(work_sessions_db.NotClaimed) ->
      api.error(409, "CONFLICT_CLAIMED", "Task is not claimed by you")

    Error(work_sessions_db.TaskDone) ->
      api.error(409, "CONFLICT_INVALID_STATE", "Task is closed")

    Error(error) -> work_session_internal_error_response(error)
  }
}

fn pause_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  with_task_id_mutation(req, fn(payload) { pause_session(ctx, user, payload) })
}

fn pause_session(
  ctx: auth.Ctx,
  user: StoredUser,
  payload: session_payloads.TaskIdPayload,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case work_sessions_db.pause_session(db, user.id, payload.task_id) {
    Ok(state) -> api.ok(session_presenters.state(state))
    Error(error) -> work_session_internal_error_response(error)
  }
}

fn heartbeat_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  with_task_id_mutation(req, fn(payload) {
    case heartbeat_rate_limit_ok(user.id, payload.task_id) {
      False -> api.error(429, "RATE_LIMITED", "Too many heartbeats")
      True -> heartbeat_session(ctx, user, payload)
    }
  })
}

fn heartbeat_session(
  ctx: auth.Ctx,
  user: StoredUser,
  payload: session_payloads.TaskIdPayload,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case work_sessions_db.heartbeat_session(db, user.id, payload.task_id) {
    Ok(state) -> api.ok(session_presenters.state(state))

    Error(work_sessions_db.SessionNotFound) ->
      api.error(404, "NOT_FOUND", "No active session for this task")

    Error(error) -> work_session_internal_error_response(error)
  }
}

fn decode_task_id_payload(
  data,
) -> Result(session_payloads.TaskIdPayload, wisp.Response) {
  session_payloads.decode_task_id(data)
  |> result.map_error(session_payload_error_to_response)
}

fn with_task_id_mutation(
  req: wisp.Request,
  handle_payload: fn(session_payloads.TaskIdPayload) -> wisp.Response,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      case decode_task_id_payload(data) {
        Error(resp) -> resp
        Ok(payload) -> handle_payload(payload)
      }
    }
  }
}

fn session_payload_error_to_response(
  error: session_payloads.DecodeError,
) -> wisp.Response {
  case error {
    session_payloads.InvalidJson ->
      api.error(422, "VALIDATION_ERROR", "Invalid JSON")
  }
}
