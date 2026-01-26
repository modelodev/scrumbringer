//// HTTP handler for current user metrics.
////
//// Provides an endpoint to retrieve task activity metrics
//// (claimed, released, completed counts) for the authenticated user.

import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/sql
import wisp

const default_window_days = 30

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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> metrics_for_user(req, ctx, user.id)
  }
}

fn metrics_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: Int,
) -> wisp.Response {
  case parse_window_days(req) {
    Error(resp) -> resp
    Ok(window_days) -> metrics_response(ctx, user_id, window_days)
  }
}

fn metrics_response(
  ctx: auth.Ctx,
  user_id: Int,
  window_days: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case sql.metrics_my(db, user_id, int.to_string(window_days)) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      api.ok(metrics_json(
        window_days,
        row.claimed_count,
        row.released_count,
        row.completed_count,
      ))

    Ok(pog.Returned(rows: [], ..)) -> api.ok(metrics_json(window_days, 0, 0, 0))

    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn metrics_json(
  window_days: Int,
  claimed_count: Int,
  released_count: Int,
  completed_count: Int,
) -> json.Json {
  json.object([
    #(
      "metrics",
      json.object([
        #("window_days", json.int(window_days)),
        #("claimed_count", json.int(claimed_count)),
        #("released_count", json.int(released_count)),
        #("completed_count", json.int(completed_count)),
      ]),
    ),
  ])
}

// Justification: nested case improves clarity for branching logic.
fn parse_window_days(req: wisp.Request) -> Result(Int, wisp.Response) {
  let query = wisp.get_query(req)

  case single_query_value(query, "window_days") {
    Ok(None) -> Ok(default_window_days)

    Ok(Some(value)) ->
      // Justification: nested case validates and bounds the parsed integer.
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
  let values =
    query
    |> list.filter_map(fn(pair) {
      case pair.0 == key {
        True -> Ok(pair.1)
        False -> Error(Nil)
      }
    })

  case values {
    [] -> Ok(None)
    [value] -> Ok(Some(value))
    _ -> Error(Nil)
  }
}
