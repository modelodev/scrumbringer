////
//// ## Mission
////
//// Handles HTTP requests for org metrics by user (admin only).
////

import gleam/http
import gleam/result

import domain/org_role
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/http/metrics_query
import scrumbringer_server/http/metrics_service
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

const max_window_days = 90

pub fn handle_org_metrics_users(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case users_payload(req, ctx) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn users_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(require_admin(user))
  use window_days <- result.try(metrics_query.parse_window_days(
    req,
    max_window_days,
  ))
  use users <- result.try(fetch_users_overview(db, user.org_id, window_days))

  Ok(api.ok(metrics_presenters.users_overview_json(users)))
}

fn require_admin(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn fetch_users_overview(
  db: pog.Connection,
  org_id: Int,
  window_days: Int,
) -> Result(List(metrics_service.UserMetricsRow), wisp.Response) {
  case metrics_service.get_users_overview(db, org_id, window_days) {
    Ok(users) -> Ok(users)
    Error(_) -> Error(database_error_response())
  }
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
