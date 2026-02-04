//// HTTP handlers for organization metrics endpoints.
////
//// ## Mission
////
//// Handles HTTP requests for admin metrics views.
//// Delegates business logic to metrics_service, JSON to metrics_presenters.
////
//// ## Responsibilities
////
//// - HTTP method and authentication checks
//// - Request parameter parsing and validation
//// - Role-based access control
//// - Response formatting via presenters
////
//// ## Non-responsibilities
////
//// - Business logic (see `metrics_service.gleam`)
//// - JSON building (see `metrics_presenters.gleam`)
//// - SQL queries (see `sql.gleam`)

import gleam/http
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

import domain/org_role
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/http/metrics_service
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

const default_window_days = 30

const max_window_days = 90

// =============================================================================
// Public Handlers
// =============================================================================

/// Handle GET /api/org/metrics/overview
///
/// Example:
///   handle_org_metrics_overview(req, ctx)
pub fn handle_org_metrics_overview(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) ->
      ensure_admin(user, fn() { overview_as_admin(req, ctx, user.org_id) })
  }
}

/// Handle GET /api/org/metrics/projects/:id/tasks
///
/// Example:
///   handle_org_metrics_project_tasks(req, ctx, "42")
pub fn handle_org_metrics_project_tasks(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) ->
      ensure_admin(user, fn() {
        project_tasks_as_admin(req, ctx, user.org_id, project_id)
      })
  }
}

// =============================================================================
// Private Handlers
// =============================================================================

// Justification: nested case improves clarity for branching logic.
fn overview_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case parse_window_days(req) {
    Error(resp) -> resp

    Ok(window_days) ->
      // Justification: nested case converts service result to HTTP response.
      case metrics_service.get_org_overview(db, org_id, window_days) {
        Ok(overview) -> api.ok(metrics_presenters.overview_json(overview))
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
  }
}

fn project_tasks_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
  project_id_raw: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case parse_project_id(project_id_raw) {
    Error(resp) -> resp
    Ok(project_id) -> project_tasks_with_id(req, db, org_id, project_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn project_tasks_with_id(
  req: wisp.Request,
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
) -> wisp.Response {
  case verify_project_org(db, project_id, org_id) {
    Error(resp) -> resp

    Ok(Nil) ->
      case parse_window_days(req) {
        Error(resp) -> resp
        Ok(window_days) ->
          project_tasks_with_window(db, project_id, window_days)
      }
  }
}

fn project_tasks_with_window(
  db: pog.Connection,
  project_id: Int,
  window_days: Int,
) -> wisp.Response {
  case metrics_service.get_project_tasks(db, project_id, window_days) {
    Ok(tasks) ->
      api.ok(metrics_presenters.project_tasks_json(
        window_days,
        project_id,
        tasks,
      ))

    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn verify_project_org(
  db: pog.Connection,
  project_id: Int,
  org_id: Int,
) -> Result(Nil, wisp.Response) {
  case metrics_service.verify_project_org(db, project_id, org_id) {
    Error(metrics_service.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(metrics_service.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Ok(False) -> Error(api.error(404, "NOT_FOUND", "Not found"))
    Ok(True) -> Ok(Nil)
  }
}

fn parse_project_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn ensure_admin(user: StoredUser, next: fn() -> wisp.Response) -> wisp.Response {
  case user.org_role {
    org_role.Admin -> next()
    _ -> api.error(403, "FORBIDDEN", "Forbidden")
  }
}

// =============================================================================
// Request Parsing
// =============================================================================

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
