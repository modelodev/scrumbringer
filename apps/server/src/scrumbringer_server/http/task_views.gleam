//// HTTP handler for task view tracking.

import gleam/http
import gleam/int
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> mark_view_for_user(req, ctx, user, task_id)
  }
}

fn mark_view_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> mark_view_with_csrf(ctx, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn mark_view_with_csrf(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp
    Ok(task_id) -> mark_view(ctx, user, task_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn mark_view(ctx: auth.Ctx, user: StoredUser, task_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case tasks_queries.get_task_for_user(db, task_id, user.id) {
    Error(tasks_queries.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(tasks_queries.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Ok(task) ->
      case authorization.is_project_member(db, user.id, task.project_id) {
        False -> api.error(404, "NOT_FOUND", "Not found")
        True -> mark_view_in_db(db, user.id, task_id)
      }
  }
}

fn mark_view_in_db(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> wisp.Response {
  case user_task_views_db.touch_task_view(db, user_id, task_id) {
    Ok(_) -> api.no_content()
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn parse_task_id(task_id: String) -> Result(Int, wisp.Response) {
  case int.parse(task_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}
