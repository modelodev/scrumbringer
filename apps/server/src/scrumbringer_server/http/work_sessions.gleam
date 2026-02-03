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

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/rate_limit
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/time
import scrumbringer_server/services/work_sessions_db
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

fn decode_task_id_data(data: dynamic.Dynamic) -> Result(Int, wisp.Response) {
  let decoder = {
    use task_id <- decode.field("task_id", decode.int)
    decode.success(task_id)
  }

  case decode.run(data, decoder) {
    Ok(task_id) -> Ok(task_id)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid JSON"))
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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> get_active_for_user(ctx, user)
  }
}

/// Handle POST /api/v1/me/work-sessions/start.
///
/// Example:
///   handle_start(req, ctx)
pub fn handle_start(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> start_for_user(req, ctx, user)
  }
}

/// Handle POST /api/v1/me/work-sessions/pause.
///
/// Example:
///   handle_pause(req, ctx)
pub fn handle_pause(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> pause_for_user(req, ctx, user)
  }
}

/// Handle POST /api/v1/me/work-sessions/heartbeat.
///
/// Example:
///   handle_heartbeat(req, ctx)
pub fn handle_heartbeat(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
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
    Ok(state) -> api.ok(state_to_json(state))
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn start_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> start_with_csrf(req, ctx, user)
  }
}

fn start_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_task_id_payload(data) {
    Error(resp) -> resp
    Ok(task_id) -> start_session(ctx, user, task_id)
  }
}

fn start_session(ctx: auth.Ctx, user: StoredUser, task_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps session errors into HTTP responses.
  case work_sessions_db.start_session(db, user.id, task_id) {
    Ok(state) -> api.ok(state_to_json(state))

    Error(work_sessions_db.NotClaimed) ->
      api.error(409, "CONFLICT_CLAIMED", "Task is not claimed by you")

    Error(work_sessions_db.TaskCompleted) ->
      api.error(409, "CONFLICT_INVALID_STATE", "Task is completed")

    Error(work_sessions_db.SessionExists) ->
      api.error(409, "CONFLICT_SESSION_EXISTS", "Session already exists")

    Error(work_sessions_db.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")

    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn pause_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> pause_with_csrf(req, ctx, user)
  }
}

fn pause_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_task_id_payload(data) {
    Error(resp) -> resp
    Ok(task_id) -> pause_session(ctx, user, task_id)
  }
}

fn pause_session(ctx: auth.Ctx, user: StoredUser, task_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case work_sessions_db.pause_session(db, user.id, task_id) {
    Ok(state) -> api.ok(state_to_json(state))
    Error(work_sessions_db.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn heartbeat_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> heartbeat_with_csrf(req, ctx, user)
  }
}

// Justification: nested case improves clarity for branching logic.
fn heartbeat_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_task_id_payload(data) {
    Error(resp) -> resp

    Ok(task_id) ->
      // Justification: nested case applies per-task heartbeat rate limits.
      case heartbeat_rate_limit_ok(user.id, task_id) {
        False -> api.error(429, "RATE_LIMITED", "Too many heartbeats")
        True -> heartbeat_session(ctx, user, task_id)
      }
  }
}

fn heartbeat_session(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case work_sessions_db.heartbeat_session(db, user.id, task_id) {
    Ok(state) -> api.ok(state_to_json(state))

    Error(work_sessions_db.SessionNotFound) ->
      api.error(404, "NOT_FOUND", "No active session for this task")

    Error(work_sessions_db.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")

    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn decode_task_id_payload(data: dynamic.Dynamic) -> Result(Int, wisp.Response) {
  decode_task_id_data(data)
}

fn state_to_json(state: work_sessions_db.WorkSessionsState) -> json.Json {
  let work_sessions_db.WorkSessionsState(
    active_sessions: sessions,
    as_of: as_of,
  ) = state

  let sessions_json =
    sessions
    |> json.array(of: fn(session) {
      let work_sessions_db.ActiveSession(
        task_id: task_id,
        started_at: started_at,
        accumulated_s: accumulated_s,
      ) = session

      json.object([
        #("task_id", json.int(task_id)),
        #("started_at", json.string(started_at)),
        #("accumulated_s", json.int(accumulated_s)),
      ])
    })

  json.object([
    #("active_sessions", sessions_json),
    #("as_of", json.string(as_of)),
  ])
}
