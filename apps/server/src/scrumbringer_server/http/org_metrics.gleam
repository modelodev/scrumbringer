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
import gleam/result

import domain/org_role
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/http/metrics_query
import scrumbringer_server/http/metrics_service
import scrumbringer_server/use_case/store_state.{type StoredUser}
import wisp

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

  case overview(req, ctx) {
    Ok(resp) -> resp
    Error(resp) -> resp
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

  case project_tasks(req, ctx, project_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

// =============================================================================
// Private Handlers
// =============================================================================

fn overview(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_admin_user(req, ctx))
  use window_days <- result.try(metrics_query.parse_window_days(
    req,
    max_window_days,
  ))
  let auth.Ctx(db: db, ..) = ctx

  case metrics_service.get_org_overview(db, user.org_id, window_days) {
    Ok(overview) -> Ok(api.ok(metrics_presenters.overview_json(overview)))
    Error(_) -> Error(database_error_response())
  }
}

fn project_tasks(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id_raw: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_admin_user(req, ctx))
  use project_id <- result.try(api.parse_id(project_id_raw))
  use window_days <- result.try(metrics_query.parse_window_days(
    req,
    max_window_days,
  ))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(verify_project_org(db, project_id, user.org_id))

  case metrics_service.get_project_tasks(db, project_id, window_days) {
    Ok(tasks) ->
      Ok(
        api.ok(metrics_presenters.project_tasks_json(
          window_days,
          project_id,
          tasks,
        )),
      )

    Error(_) -> Error(database_error_response())
  }
}

fn verify_project_org(
  db: pog.Connection,
  project_id: Int,
  org_id: Int,
) -> Result(Nil, wisp.Response) {
  case metrics_service.verify_project_org(db, project_id, org_id) {
    Error(metrics_service.NotFound) -> Error(not_found_response())
    Error(metrics_service.DbError(_)) -> Error(database_error_response())
    Error(metrics_service.InvalidTaskExecutionState(_)) ->
      Error(database_error_response())
    Ok(False) -> Error(not_found_response())
    Ok(True) -> Ok(Nil)
  }
}

fn require_admin_user(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  case user.org_role {
    org_role.Admin -> Ok(user)
    _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

// =============================================================================
// Request Parsing
// =============================================================================

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
