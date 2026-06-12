//// Shared HTTP flow for per-user resource view tracking.

import gleam/http
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/authorization
import wisp

pub fn handle_put(
  req: wisp.Request,
  ctx: auth.Ctx,
  resource_id: String,
  fetch_project_id: fn(pog.Connection, Int, Int) -> Result(Int, wisp.Response),
  touch_view: fn(pog.Connection, Int, Int) -> Result(a, pog.QueryError),
) -> wisp.Response {
  case req.method {
    http.Put ->
      put(req, ctx, resource_id, fetch_project_id, touch_view)
    _ -> wisp.method_not_allowed([http.Put])
  }
}

fn put(
  req: wisp.Request,
  ctx: auth.Ctx,
  resource_id: String,
  fetch_project_id: fn(pog.Connection, Int, Int) -> Result(Int, wisp.Response),
  touch_view: fn(pog.Connection, Int, Int) -> Result(a, pog.QueryError),
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case mark_view_payload(req, ctx, resource_id, fetch_project_id, touch_view) {
    Ok(Nil) -> api.no_content()
    Error(resp) -> resp
  }
}

fn mark_view_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  resource_id: String,
  fetch_project_id: fn(pog.Connection, Int, Int) -> Result(Int, wisp.Response),
  touch_view: fn(pog.Connection, Int, Int) -> Result(a, pog.QueryError),
) -> Result(Nil, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use resource_id <- result.try(api.parse_id(resource_id))

  mark_view(ctx, user.id, resource_id, fetch_project_id, touch_view)
}

fn mark_view(
  ctx: auth.Ctx,
  user_id: Int,
  resource_id: Int,
  fetch_project_id: fn(pog.Connection, Int, Int) -> Result(Int, wisp.Response),
  touch_view: fn(pog.Connection, Int, Int) -> Result(a, pog.QueryError),
) -> Result(Nil, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use project_id <- result.try(fetch_project_id(db, resource_id, user_id))
  use Nil <- result.try(require_project_member(db, user_id, project_id))

  case touch_view(db, user_id, resource_id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(database_error_response())
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
