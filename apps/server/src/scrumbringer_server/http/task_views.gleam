//// HTTP handler for task view tracking.

import gleam/http
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/service_error_response
import scrumbringer_server/persistence/tasks/mappers.{type Task}
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/authorization
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/user_task_views_db
import wisp

/// Routes PUT /api/v1/views/tasks/:id requests.
pub fn handle_task_view(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case req.method {
    http.Put -> handle_put(req, ctx, task_id)
    _ -> wisp.method_not_allowed([http.Put])
  }
}

fn handle_put(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case mark_view_payload(req, ctx, task_id) {
    Ok(Nil) -> api.no_content()
    Error(resp) -> resp
  }
}

fn mark_view_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> Result(Nil, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use task_id <- result.try(api.parse_id(task_id))

  mark_view(ctx, user, task_id)
}

fn mark_view(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
) -> Result(Nil, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use task <- result.try(fetch_task(db, task_id, user.id))
  use Nil <- result.try(require_project_member(db, user.id, task.project_id))

  mark_view_in_db(db, user.id, task_id)
}

fn mark_view_in_db(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(Nil, wisp.Response) {
  case user_task_views_db.touch_task_view(db, user_id, task_id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(database_error_response())
  }
}

fn fetch_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Task, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(task)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn require_project_member(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case authorization.is_project_member(db, user_id, project_id) {
    True -> Ok(Nil)
    False -> Error(not_found_response())
  }
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
