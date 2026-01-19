//// HTTP handlers for work sessions (multi-session time tracking).
////
//// ## Mission
////
//// Handles HTTP requests for work session operations.
//// Supports multiple concurrent sessions per user.
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

/// Handle GET /api/v1/me/work-sessions/active
pub fn handle_get_active(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      // Lazy cleanup: close stale sessions before returning active list.
      let _ = work_sessions_db.close_stale_sessions(db)

      case work_sessions_db.get_active_sessions(db, user.id) {
        Ok(state) -> api.ok(state_to_json(state))
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

/// Handle POST /api/v1/me/work-sessions/start
pub fn handle_start(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          use data <- wisp.require_json(req)

          case decode_task_id_data(data) {
            Error(resp) -> resp

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case work_sessions_db.start_session(db, user.id, task_id) {
                Ok(state) -> api.ok(state_to_json(state))

                Error(work_sessions_db.NotClaimed) ->
                  api.error(
                    409,
                    "CONFLICT_CLAIMED",
                    "Task is not claimed by you",
                  )

                Error(work_sessions_db.TaskCompleted) ->
                  api.error(409, "CONFLICT_INVALID_STATE", "Task is completed")

                Error(work_sessions_db.SessionExists) ->
                  api.error(
                    409,
                    "CONFLICT_SESSION_EXISTS",
                    "Session already exists",
                  )

                Error(work_sessions_db.DbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")

                Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
              }
            }
          }
        }
      }
  }
}

/// Handle POST /api/v1/me/work-sessions/pause
pub fn handle_pause(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          use data <- wisp.require_json(req)

          case decode_task_id_data(data) {
            Error(resp) -> resp

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case work_sessions_db.pause_session(db, user.id, task_id) {
                Ok(state) -> api.ok(state_to_json(state))

                Error(work_sessions_db.DbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")

                Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
              }
            }
          }
        }
      }
  }
}

/// Handle POST /api/v1/me/work-sessions/heartbeat
pub fn handle_heartbeat(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          use data <- wisp.require_json(req)

          case decode_task_id_data(data) {
            Error(resp) -> resp

            Ok(task_id) ->
              case heartbeat_rate_limit_ok(user.id, task_id) {
                False -> api.error(429, "RATE_LIMITED", "Too many heartbeats")

                True -> {
                  let auth.Ctx(db: db, ..) = ctx

                  case
                    work_sessions_db.heartbeat_session(db, user.id, task_id)
                  {
                    Ok(state) -> api.ok(state_to_json(state))

                    Error(work_sessions_db.SessionNotFound) ->
                      api.error(
                        404,
                        "NOT_FOUND",
                        "No active session for this task",
                      )

                    Error(work_sessions_db.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")

                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
                }
              }
          }
        }
      }
  }
}

// =============================================================================
// JSON Serialization
// =============================================================================

fn state_to_json(state: work_sessions_db.WorkSessionsState) -> json.Json {
  json.object([
    #("active_sessions", json.array(state.active_sessions, of: session_to_json)),
    #("as_of", json.string(state.as_of)),
  ])
}

fn session_to_json(session: work_sessions_db.ActiveSession) -> json.Json {
  json.object([
    #("task_id", json.int(session.task_id)),
    #("started_at", json.string(session.started_at)),
    #("accumulated_s", json.int(session.accumulated_s)),
  ])
}
