////
//// ## Mission
////
//// Handles HTTP requests for org metrics by user (admin only).
////

import gleam/http
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

import domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/http/metrics_service
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

const default_window_days = 30

const max_window_days = 90

pub fn handle_org_metrics_users(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) ->
      ensure_admin(user, fn() { users_as_admin(req, ctx, user.org_id) })
  }
}

fn users_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case parse_window_days(req) {
    Error(resp) -> resp
    Ok(window_days) ->
      case metrics_service.get_users_overview(db, org_id, window_days) {
        Ok(users) -> api.ok(metrics_presenters.users_overview_json(users))
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
  }
}

fn ensure_admin(user: StoredUser, next: fn() -> wisp.Response) -> wisp.Response {
  case user.org_role {
    org_role.Admin -> next()
    _ -> api.error(403, "FORBIDDEN", "Forbidden")
  }
}

fn parse_window_days(req: wisp.Request) -> Result(Int, wisp.Response) {
  let query = wisp.get_query(req)

  case single_query_value(query, "window_days") {
    Ok(None) -> Ok(default_window_days)
    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(days) if days >= 1 && days <= max_window_days -> Ok(days)
        _ -> Error(api.error(422, "VALIDATION_ERROR", "Invalid window_days"))
      }
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid window_days"))
  }
}

fn single_query_value(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(String), Nil) {
  case
    query
    |> list.filter(fn(pair) {
      let #(k, _) = pair
      k == key
    })
  {
    [] -> Ok(None)
    [#(_, value), ..] -> Ok(Some(value))
  }
}
