import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/now_working_db
import wisp

pub fn handle_me_active_task(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case build_payload(db, user.id) {
        Ok(payload) -> api.ok(payload)
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

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

              case now_working_db.start(db, user.id, task_id) {
                Ok(_) ->
                  case build_payload(db, user.id) {
                    Ok(payload) -> api.ok(payload)
                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }

                Error(now_working_db.NotClaimed) ->
                  api.error(
                    409,
                    "CONFLICT_CLAIMED",
                    "Task is not claimed by you",
                  )

                Error(now_working_db.DbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")
              }
            }
          }
        }
      }
  }
}

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

          case now_working_db.pause(db, user.id) {
            Ok(_) ->
              case build_payload(db, user.id) {
                Ok(payload) -> api.ok(payload)
                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }

            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn build_payload(
  db: pog.Connection,
  user_id: Int,
) -> Result(json.Json, pog.QueryError) {
  use active_task <- result.try(now_working_db.get_active_task(db, user_id))
  use as_of <- result.try(now_working_db.as_of(db))

  let active_task = case active_task {
    Some(active) -> active_task_json(active)
    None -> json.null()
  }

  Ok(
    json.object([
      #("active_task", active_task),
      #("as_of", json.string(as_of)),
    ]),
  )
}

fn active_task_json(task: now_working_db.ActiveTask) -> json.Json {
  let now_working_db.ActiveTask(
    task_id: task_id,
    project_id: project_id,
    started_at: started_at,
  ) = task

  json.object([
    #("task_id", json.int(task_id)),
    #("project_id", json.int(project_id)),
    #("started_at", json.string(started_at)),
  ])
}
