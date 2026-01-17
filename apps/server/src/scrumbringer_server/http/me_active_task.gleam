//// HTTP handlers for active task (now working) endpoints.
////
//// ## Mission
////
//// Handles HTTP requests for active task operations.
//// Delegates business logic to now_working_actor.
////
//// ## Responsibilities
////
//// - HTTP method validation
//// - Authentication checks
//// - Request body parsing
//// - CSRF validation
//// - Response JSON construction
////
//// ## Non-responsibilities
////
//// - Business logic (see `services/now_working_actor.gleam`)
//// - Database operations (see `services/now_working_db.gleam`)

import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/now_working_actor
import scrumbringer_server/services/now_working_db
import wisp

// =============================================================================
// Public Handlers
// =============================================================================

/// Handle GET /api/me/active-task
pub fn handle_me_active_task(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case
        now_working_actor.handle(db, now_working_actor.GetActiveTask(user.id))
      {
        Ok(state) -> api.ok(state_to_json(state))
        Error(now_working_actor.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
      }
    }
  }
}

/// Handle POST /api/me/active-task/start
pub fn handle_me_active_task_start(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          use data <- wisp.require_json(req)

          let decoder = {
            use task_id <- decode.field("task_id", decode.int)
            decode.success(task_id)
          }

          case decode.run(data, decoder) {
            Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid JSON")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case
                now_working_actor.handle(
                  db,
                  now_working_actor.StartActiveTask(user.id, task_id),
                )
              {
                Ok(state) -> api.ok(state_to_json(state))

                Error(now_working_actor.TaskNotClaimed) ->
                  api.error(
                    409,
                    "CONFLICT_CLAIMED",
                    "Task is not claimed by you",
                  )

                Error(now_working_actor.DbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")
              }
            }
          }
        }
      }
  }
}

/// Handle POST /api/me/active-task/pause
pub fn handle_me_active_task_pause(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            now_working_actor.handle(
              db,
              now_working_actor.PauseActiveTask(user.id),
            )
          {
            Ok(state) -> api.ok(state_to_json(state))
            Error(now_working_actor.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
          }
        }
      }
  }
}

/// Handle POST /api/me/active-task/heartbeat
pub fn handle_me_active_task_heartbeat(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            now_working_actor.handle(db, now_working_actor.Heartbeat(user.id))
          {
            Ok(state) -> api.ok(state_to_json(state))
            Error(now_working_actor.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
          }
        }
      }
  }
}

// =============================================================================
// JSON Serialization
// =============================================================================

fn state_to_json(state: now_working_actor.ActiveTaskState) -> json.Json {
  let active_task = case state.active_task {
    Some(active) -> active_task_json(active)
    None -> json.null()
  }

  json.object([
    #("active_task", active_task),
    #("as_of", json.string(state.as_of)),
  ])
}

fn active_task_json(task: now_working_db.ActiveTask) -> json.Json {
  let now_working_db.ActiveTask(
    task_id: task_id,
    project_id: project_id,
    started_at: started_at,
    accumulated_s: accumulated_s,
  ) = task

  json.object([
    #("task_id", json.int(task_id)),
    #("project_id", json.int(project_id)),
    #("started_at", json.string(started_at)),
    #("accumulated_s", json.int(accumulated_s)),
  ])
}
