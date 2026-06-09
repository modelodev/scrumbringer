//// HTTP handler for current user metrics.
////
//// Provides an endpoint to retrieve task activity metrics
//// (claimed, released, completed counts) for the authenticated user.

import gleam/http
import gleam/int
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/http/metrics_query
import scrumbringer_server/sql
import wisp

const max_window_days = 365

/// Handles GET /api/me/metrics to return user activity metrics.
///
/// Accepts an optional `window_days` query param (1-365, default 30).
///
/// ## Example
///
/// ```gleam
/// handle_me_metrics(req, ctx)
/// // -> { "metrics": { "window_days": 30, "claimed_count": 5, ... } }
/// ```
pub fn handle_me_metrics(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case me_metrics(req, ctx) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn me_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use window_days <- result.try(metrics_query.parse_window_days(
    req,
    max_window_days,
  ))
  let auth.Ctx(db: db, ..) = ctx

  case sql.metrics_my(db, user.id, int.to_string(window_days)) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(
        api.ok(metrics_presenters.me_metrics_json(
          window_days,
          row.claimed_count,
          row.released_count,
          row.completed_count,
        )),
      )

    Ok(pog.Returned(rows: [], ..)) ->
      Ok(api.ok(metrics_presenters.me_metrics_json(window_days, 0, 0, 0)))

    Error(_) -> Error(database_error_response())
  }
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
