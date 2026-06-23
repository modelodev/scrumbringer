//// HTTP handlers for rule metrics endpoints.
////
//// ## Mission
////
//// Serve read-only rule metrics for admins across workflows, rules, and
//// execution drill-downs.
////
//// ## Responsibilities
////
//// - Parse query parameters for date ranges and pagination
//// - Authorize access for admin users
//// - Assemble JSON responses from metrics queries
////
//// ## Non-responsibilities
////
//// - Computing metrics (see `use_case/rule_metrics_db.gleam`)
//// - Defining rules or workflows (see `use_case/rules_db.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for session identity
//// - Delegates data access to `use_case/rule_metrics_db.gleam`
//// - Maps domain rows into JSON responses in this module

import domain/org_role.{Admin}
import gleam/http
import gleam/int
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/query as query_params
import scrumbringer_server/http/rule_metrics/presenters
import scrumbringer_server/use_case/projects_db
import scrumbringer_server/use_case/rule_metrics_db
import scrumbringer_server/use_case/rules_db
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/workflows_db
import wisp

// =============================================================================
// Constants
// =============================================================================

const default_days = 30

const max_days = 90

const default_limit = 50

const max_limit = 100

type RangeBoundary {
  RangeStart
  RangeEnd
}

// =============================================================================
// Routing
// =============================================================================

/// Routes workflow metrics requests (GET only).
///
/// Example:
///   handle_workflow_metrics(req, ctx, workflow_id)
pub fn handle_workflow_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> get_workflow_metrics(req, ctx, workflow_id)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

/// Routes rule metrics requests (GET only).
///
/// Example:
///   handle_rule_metrics(req, ctx, rule_id)
pub fn handle_rule_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> get_rule_metrics(req, ctx, rule_id)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

/// Routes rule execution drill-down requests (GET only).
///
/// Example:
///   handle_rule_executions(req, ctx, rule_id)
pub fn handle_rule_executions(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> get_rule_executions(req, ctx, rule_id)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

/// Routes organization metrics requests (GET only).
///
/// Example:
///   handle_org_metrics(req, ctx)
pub fn handle_org_metrics(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> get_org_metrics(req, ctx)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

/// Routes project metrics requests (GET only).
///
/// Example:
///   handle_project_metrics(req, ctx, project_id)
pub fn handle_project_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> get_project_metrics(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

// =============================================================================
// Handlers
// =============================================================================

fn get_workflow_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case workflow_metrics(req, ctx, workflow_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn workflow_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use workflow_id <- result.try(api.parse_id(workflow_id))
  let auth.Ctx(db: db, ..) = ctx
  use workflow <- result.try(fetch_workflow(db, workflow_id, "Not found"))
  use _ <- result.try(require_workflow_access(db, user, workflow))
  use #(from, to) <- result.try(parse_date_range(req))

  case rule_metrics_db.get_workflow_metrics(db, workflow_id, from, to) {
    Ok(rules) ->
      Ok(
        api.ok(presenters.workflow_metrics_json(
          workflow_id,
          workflow.name,
          from,
          to,
          rules,
        )),
      )
    Error(_) -> Error(database_error_response())
  }
}

fn get_rule_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case rule_metrics(req, ctx, rule_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn rule_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> Result(wisp.Response, wisp.Response) {
  use #(db, rule_id) <- result.try(require_rule_metrics_access(
    req,
    ctx,
    rule_id,
  ))
  use #(from, to) <- result.try(parse_date_range(req))

  case rule_metrics_db.get_rule_metrics(db, rule_id, from, to) {
    Ok(Some(metrics)) ->
      Ok(api.ok(presenters.rule_metrics_json(metrics, from, to)))
    Ok(None) -> Error(api.error(404, "NOT_FOUND", "Rule not found"))
    Error(_) -> Error(database_error_response())
  }
}

fn get_rule_executions(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case rule_executions(req, ctx, rule_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn rule_executions(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> Result(wisp.Response, wisp.Response) {
  use #(db, rule_id) <- result.try(require_rule_metrics_access(
    req,
    ctx,
    rule_id,
  ))
  use #(from, to) <- result.try(parse_date_range(req))
  use #(limit, offset) <- result.try(parse_pagination(req))

  case
    rule_metrics_db.list_rule_executions(db, rule_id, from, to, limit, offset)
  {
    Ok(executions) -> {
      use total <- result.try(count_rule_executions(db, rule_id, from, to))
      Ok(
        api.ok(presenters.rule_executions_json(
          rule_id,
          executions,
          limit,
          offset,
          total,
        )),
      )
    }
    Error(_) -> Error(database_error_response())
  }
}

fn count_rule_executions(
  db: pog.Connection,
  rule_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(Int, wisp.Response) {
  case rule_metrics_db.count_rule_executions(db, rule_id, from, to) {
    Ok(total) -> Ok(total)
    Error(_) -> Error(database_error_response())
  }
}

fn get_org_metrics(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case org_metrics(req, ctx) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn org_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(require_admin_role(user))
  use #(from, to) <- result.try(parse_date_range(req))
  let auth.Ctx(db: db, ..) = ctx

  case rule_metrics_db.get_org_metrics_summary(db, user.org_id, from, to) {
    Ok(workflows) ->
      Ok(api.ok(presenters.org_metrics_json(from, to, workflows)))
    Error(_) -> Error(database_error_response())
  }
}

fn get_project_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case project_metrics(req, ctx, project_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn authorize_project_metrics(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_manager(db, project_id, user.id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> require_admin_role(user)
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn require_admin_role(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    Admin -> Ok(Nil)
    _ -> Error(api.error(403, "FORBIDDEN", "Admin role required"))
  }
}

fn project_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use project_id <- result.try(api.parse_id(project_id))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(authorize_project_metrics(db, user, project_id))
  use #(from, to) <- result.try(parse_date_range(req))

  case rule_metrics_db.get_project_metrics_summary(db, project_id, from, to) {
    Ok(workflows) ->
      Ok(
        api.ok(presenters.project_metrics_json(project_id, from, to, workflows)),
      )
    Error(_) -> Error(database_error_response())
  }
}

fn require_rule_metrics_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> Result(#(pog.Connection, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use rule_id <- result.try(api.parse_id(rule_id))
  let auth.Ctx(db: db, ..) = ctx
  use rule <- result.try(fetch_rule(db, rule_id))
  use _workflow <- result.try(workflow_from_rule(db, user, rule))
  Ok(#(db, rule_id))
}

fn fetch_rule(
  db: pog.Connection,
  rule_id: Int,
) -> Result(rules_db.RuleRecord, wisp.Response) {
  case rules_db.get_rule(db, rule_id) {
    Ok(rule) -> Ok(rule)
    Error(_) -> Error(not_found_response())
  }
}

fn fetch_workflow(
  db: pog.Connection,
  workflow_id: Int,
  message: String,
) -> Result(workflows_db.WorkflowRecord, wisp.Response) {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(workflow)
    Error(_) -> Error(api.error(404, "NOT_FOUND", message))
  }
}

fn workflow_from_rule(
  db,
  user: StoredUser,
  rule: rules_db.RuleRecord,
) -> Result(workflows_db.WorkflowRecord, wisp.Response) {
  case workflows_db.get_workflow(db, rule.workflow_id) {
    Ok(workflow) -> authorize_workflow_access(db, user, workflow)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Workflow not found"))
  }
}

fn require_workflow_access(
  db: pog.Connection,
  user: StoredUser,
  workflow: workflows_db.WorkflowRecord,
) -> Result(Nil, wisp.Response) {
  authorization.require_project_manager_with_org_bypass(
    db,
    user,
    workflow.project_id,
  )
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}

fn authorize_workflow_access(
  db: pog.Connection,
  user: StoredUser,
  workflow: workflows_db.WorkflowRecord,
) -> Result(workflows_db.WorkflowRecord, wisp.Response) {
  case
    authorization.require_project_manager_with_org_bypass(
      db,
      user,
      workflow.project_id,
    )
  {
    Ok(Nil) -> Ok(workflow)
    Error(resp) -> Error(resp)
  }
}

// =============================================================================
// Query Parameter Parsing
// =============================================================================

fn parse_date_range(
  req: wisp.Request,
) -> Result(#(Timestamp, Timestamp), wisp.Response) {
  let now = timestamp.system_time()
  // 30 days in seconds (negative for subtraction)
  let thirty_days_ago = duration.seconds(-default_days * 86_400)
  let default_from_ts = timestamp.add(now, thirty_days_ago)
  parse_date_range_query(wisp.get_query(req), default_from_ts, now)
}

pub fn parse_date_range_query(
  query: List(#(String, String)),
  default_from_ts: Timestamp,
  default_to_ts: Timestamp,
) -> Result(#(Timestamp, Timestamp), wisp.Response) {
  use from <- result.try(parse_optional_calendar_date(
    query,
    "from",
    default_from_ts,
    RangeStart,
  ))
  use to <- result.try(parse_optional_calendar_date(
    query,
    "to",
    default_to_ts,
    RangeEnd,
  ))

  // Validate from <= to
  let range = timestamp.difference(to, from)
  let zero = duration.seconds(0)
  validate_range_order(range, from, to, zero)
}

fn parse_optional_calendar_date(
  query: List(#(String, String)),
  key: String,
  default: Timestamp,
  boundary: RangeBoundary,
) -> Result(Timestamp, wisp.Response) {
  case query_params.single_value(query, key) {
    Ok(None) -> Ok(default)
    Ok(Some(value)) -> parse_calendar_date(value, key, boundary)
    Error(_) -> Error(invalid_query_response(key))
  }
}

fn parse_calendar_date(
  value: String,
  key: String,
  boundary: RangeBoundary,
) -> Result(Timestamp, wisp.Response) {
  case string.length(value) == 10 {
    True ->
      case timestamp.parse_rfc3339(calendar_boundary(value, boundary)) {
        Ok(ts) -> Ok(ts)
        Error(_) -> Error(invalid_query_response(key))
      }
    False -> Error(invalid_query_response(key))
  }
}

fn calendar_boundary(value: String, boundary: RangeBoundary) -> String {
  case boundary {
    RangeStart -> value <> "T00:00:00Z"
    RangeEnd -> value <> "T23:59:59.999999999Z"
  }
}

fn validate_range_order(
  range: duration.Duration,
  from: Timestamp,
  to: Timestamp,
  zero: duration.Duration,
) -> Result(#(Timestamp, Timestamp), wisp.Response) {
  case duration.compare(range, zero) {
    order.Lt ->
      Error(api.error(
        422,
        "INVALID_DATE_RANGE",
        "Start date must be before or equal to end date",
      ))
    _ -> validate_range_limit(range, from, to)
  }
}

fn validate_range_limit(
  range: duration.Duration,
  from: Timestamp,
  to: Timestamp,
) -> Result(#(Timestamp, Timestamp), wisp.Response) {
  let max_range = duration.seconds(max_days * 86_400)
  case duration.compare(range, max_range) {
    order.Gt ->
      Error(api.error(
        400,
        "INVALID_DATE_RANGE",
        "Date range cannot exceed 90 days",
      ))
    _ -> Ok(#(from, to))
  }
}

fn parse_pagination(req: wisp.Request) -> Result(#(Int, Int), wisp.Response) {
  parse_pagination_query(wisp.get_query(req))
}

pub fn parse_pagination_query(
  query: List(#(String, String)),
) -> Result(#(Int, Int), wisp.Response) {
  use limit <- result.try(parse_limit(query))
  use offset <- result.try(parse_offset(query))
  Ok(#(limit, offset))
}

fn parse_limit(query: List(#(String, String))) -> Result(Int, wisp.Response) {
  case query_params.single_value(query, "limit") {
    Ok(None) -> Ok(default_limit)
    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(limit) if limit >= 1 && limit <= max_limit -> Ok(limit)
        _ -> Error(invalid_query_response("limit"))
      }
    Error(_) -> Error(invalid_query_response("limit"))
  }
}

fn parse_offset(query: List(#(String, String))) -> Result(Int, wisp.Response) {
  case query_params.single_value(query, "offset") {
    Ok(None) -> Ok(0)
    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(offset) if offset >= 0 -> Ok(offset)
        _ -> Error(invalid_query_response("offset"))
      }
    Error(_) -> Error(invalid_query_response("offset"))
  }
}

fn invalid_query_response(key: String) -> wisp.Response {
  api.error(422, "VALIDATION_ERROR", "Invalid " <> key)
}
