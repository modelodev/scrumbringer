////
//// HTTP handlers for rule metrics endpoints.
////
//// Provides read-only access to rule execution metrics for admin users.
//// Includes workflow-level aggregates, rule-level details with suppression
//// breakdown, and drill-down to individual executions.

import domain/org_role.{Admin}
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/rule_metrics_db
import scrumbringer_server/services/rules_db
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/workflows_db
import wisp

// =============================================================================
// Constants
// =============================================================================

const default_days = 30

const max_days = 90

const default_limit = 50

const max_limit = 100

// =============================================================================
// Routing
// =============================================================================

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

pub fn handle_org_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  case req.method {
    http.Get -> get_org_metrics(req, ctx)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

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
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(workflow_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(workflow_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case workflows_db.get_workflow(db, workflow_id) {
            Ok(workflow) ->
              case authorization.require_project_manager_with_org_bypass(
                  db,
                  user,
                  workflow.project_id,
                ) {
                Error(resp) -> resp
                Ok(Nil) ->
                  case parse_date_range(req) {
                    Error(resp) -> resp
                    Ok(#(from, to)) ->
                      case
                        rule_metrics_db.get_workflow_metrics(
                          db,
                          workflow_id,
                          from,
                          to,
                        )
                      {
                        Ok(rules) -> {
                          let totals = calculate_totals(rules)
                          api.ok(
                            json.object([
                              #("workflow_id", json.int(workflow_id)),
                              #("workflow_name", json.string(workflow.name)),
                              #("from", json.string(timestamp_to_string(from))),
                              #("to", json.string(timestamp_to_string(to))),
                              #(
                                "rules",
                                json.array(rules, of: rule_metrics_summary_json),
                              ),
                              #("totals", totals_json(totals)),
                            ]),
                          )
                        }
                        Error(_) -> api.error(500, "INTERNAL", "Database error")
                      }
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn get_rule_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(rule_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(rule_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case rules_db.get_rule(db, rule_id) {
            Ok(rule) ->
              case workflow_from_rule(db, user, rule) {
                Error(resp) -> resp
                Ok(_workflow) ->
                  case parse_date_range(req) {
                    Error(resp) -> resp
                    Ok(#(from, to)) ->
                      case rule_metrics_db.get_rule_metrics(db, rule_id, from, to)
                      {
                        Ok(Some(metrics)) ->
                          api.ok(
                            json.object([
                              #("rule_id", json.int(metrics.rule_id)),
                              #("rule_name", json.string(metrics.rule_name)),
                              #("from", json.string(timestamp_to_string(from))),
                              #("to", json.string(timestamp_to_string(to))),
                              #(
                                "evaluated_count",
                                json.int(metrics.evaluated_count),
                              ),
                              #("applied_count", json.int(metrics.applied_count)),
                              #(
                                "suppressed_count",
                                json.int(metrics.suppressed_count),
                              ),
                              #(
                                "suppression_breakdown",
                                json.object([
                                  #(
                                    "idempotent",
                                    json.int(metrics.suppressed_idempotent),
                                  ),
                                  #(
                                    "not_user_triggered",
                                    json.int(metrics.suppressed_not_user),
                                  ),
                                  #(
                                    "not_matching",
                                    json.int(metrics.suppressed_not_matching),
                                  ),
                                  #(
                                    "inactive",
                                    json.int(metrics.suppressed_inactive),
                                  ),
                                ]),
                              ),
                            ]),
                          )
                        Ok(None) ->
                          api.error(404, "NOT_FOUND", "Rule not found")
                        Error(_) ->
                          api.error(500, "INTERNAL", "Database error")
                      }
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn get_rule_executions(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(rule_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(rule_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case rules_db.get_rule(db, rule_id) {
            Ok(rule) ->
              case workflow_from_rule(db, user, rule) {
                Error(resp) -> resp
                Ok(_workflow) ->
                  case parse_date_range(req) {
                    Error(resp) -> resp
                    Ok(#(from, to)) -> {
                      let #(limit, offset) = parse_pagination(req)

                      case
                        rule_metrics_db.list_rule_executions(
                          db,
                          rule_id,
                          from,
                          to,
                          limit,
                          offset,
                        )
                      {
                        Ok(executions) ->
                          case
                            rule_metrics_db.count_rule_executions(
                              db,
                              rule_id,
                              from,
                              to,
                            )
                          {
                            Ok(total) ->
                              api.ok(
                                json.object([
                                  #("rule_id", json.int(rule_id)),
                                  #(
                                    "executions",
                                    json.array(executions, of: execution_json),
                                  ),
                                  #(
                                    "pagination",
                                    json.object([
                                      #("limit", json.int(limit)),
                                      #("offset", json.int(offset)),
                                      #("total", json.int(total)),
                                    ]),
                                  ),
                                ]),
                              )
                            Error(_) ->
                              api.error(500, "INTERNAL", "Database error")
                          }
                        Error(_) -> api.error(500, "INTERNAL", "Database error")
                      }
                    }
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn get_org_metrics(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case user.org_role {
        Admin ->
          case parse_date_range(req) {
            Error(resp) -> resp
            Ok(#(from, to)) -> {
              let auth.Ctx(db: db, ..) = ctx

              case
                rule_metrics_db.get_org_metrics_summary(
                  db,
                  user.org_id,
                  from,
                  to,
                )
              {
                Ok(workflows) -> {
                  let totals = calculate_workflow_totals(workflows)
                  api.ok(
                    json.object([
                      #("from", json.string(timestamp_to_string(from))),
                      #("to", json.string(timestamp_to_string(to))),
                      #(
                        "workflows",
                        json.array(workflows, of: workflow_summary_json),
                      ),
                      #("totals", totals_json(totals)),
                    ]),
                  )
                }
                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }
            }
          }
        _ -> api.error(403, "FORBIDDEN", "Admin role required")
      }
  }
}

fn get_project_metrics(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          // Verify user is admin of this project's org or a project admin
          case projects_db.is_project_manager(db, user.id, project_id) {
            Ok(True) ->
              case parse_date_range(req) {
                Error(resp) -> resp
                Ok(#(from, to)) ->
                  do_get_project_metrics(db, project_id, from, to)
              }
            Ok(False) ->
              case user.org_role {
                Admin ->
                  case parse_date_range(req) {
                    Error(resp) -> resp
                    Ok(#(from, to)) ->
                      do_get_project_metrics(db, project_id, from, to)
                  }
                _ -> api.error(403, "FORBIDDEN", "Admin role required")
              }
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn do_get_project_metrics(
  db: pog.Connection,
  project_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> wisp.Response {
  case rule_metrics_db.get_project_metrics_summary(db, project_id, from, to) {
    Ok(workflows) -> {
      let totals = calculate_workflow_totals(workflows)
      api.ok(
        json.object([
          #("project_id", json.int(project_id)),
          #("from", json.string(timestamp_to_string(from))),
          #("to", json.string(timestamp_to_string(to))),
          #("workflows", json.array(workflows, of: workflow_summary_json)),
          #("totals", totals_json(totals)),
        ]),
      )
    }
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn workflow_from_rule(
  db,
  user: StoredUser,
  rule: rules_db.Rule,
) -> Result(workflows_db.Workflow, wisp.Response) {
  case workflows_db.get_workflow(db, rule.workflow_id) {
    Ok(workflow) ->
      case authorization.require_project_manager_with_org_bypass(
                  db,
                  user,
                  workflow.project_id,
                ) {
        Ok(Nil) -> Ok(workflow)
        Error(resp) -> Error(resp)
      }
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Workflow not found"))
  }
}

// =============================================================================
// Query Parameter Parsing
// =============================================================================

fn parse_date_range(
  req: wisp.Request,
) -> Result(#(Timestamp, Timestamp), wisp.Response) {
  let query = wisp.get_query(req)
  let now = timestamp.system_time()
  // 30 days in seconds (negative for subtraction)
  let thirty_days_ago = duration.seconds(-default_days * 86_400)
  let default_from_ts = timestamp.add(now, thirty_days_ago)

  let from =
    list.find(query, fn(pair) { pair.0 == "from" })
    |> result.try(fn(pair) { timestamp.parse_rfc3339(pair.1) })
    |> result.unwrap(default_from_ts)

  let to =
    list.find(query, fn(pair) { pair.0 == "to" })
    |> result.try(fn(pair) { timestamp.parse_rfc3339(pair.1) })
    |> result.unwrap(now)

  // Validate from <= to
  let range = timestamp.difference(to, from)
  let zero = duration.seconds(0)
  case duration.compare(range, zero) {
    order.Lt ->
      Error(api.error(
        422,
        "INVALID_DATE_RANGE",
        "Start date must be before or equal to end date",
      ))
    _ -> {
      // Validate max range (90 days)
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
  }
}

fn parse_pagination(req: wisp.Request) -> #(Int, Int) {
  let query = wisp.get_query(req)

  let limit =
    list.find(query, fn(pair) { pair.0 == "limit" })
    |> result.try(fn(pair) { int.parse(pair.1) })
    |> result.unwrap(default_limit)
    |> int.min(max_limit)
    |> int.max(1)

  let offset =
    list.find(query, fn(pair) { pair.0 == "offset" })
    |> result.try(fn(pair) { int.parse(pair.1) })
    |> result.unwrap(0)
    |> int.max(0)

  #(limit, offset)
}

fn timestamp_to_string(ts: Timestamp) -> String {
  timestamp.to_rfc3339(ts, duration.seconds(0))
}

// =============================================================================
// JSON Serialization
// =============================================================================

fn rule_metrics_summary_json(metrics: rule_metrics_db.RuleMetricsSummary) -> json.Json {
  json.object([
    #("rule_id", json.int(metrics.rule_id)),
    #("rule_name", json.string(metrics.rule_name)),
    #("active", json.bool(metrics.active)),
    #("evaluated_count", json.int(metrics.evaluated_count)),
    #("applied_count", json.int(metrics.applied_count)),
    #("suppressed_count", json.int(metrics.suppressed_count)),
  ])
}

fn workflow_summary_json(summary: rule_metrics_db.WorkflowMetricsSummary) -> json.Json {
  json.object([
    #("workflow_id", json.int(summary.workflow_id)),
    #("workflow_name", json.string(summary.workflow_name)),
    #("project_id", option_json(summary.project_id, json.int)),
    #("rule_count", json.int(summary.rule_count)),
    #("evaluated_count", json.int(summary.evaluated_count)),
    #("applied_count", json.int(summary.applied_count)),
    #("suppressed_count", json.int(summary.suppressed_count)),
  ])
}

fn execution_json(exec: rule_metrics_db.RuleExecution) -> json.Json {
  // Build base required fields
  let fields = [
    #("id", json.int(exec.id)),
    #("origin_type", json.string(exec.origin_type)),
    #("origin_id", json.int(exec.origin_id)),
    #("outcome", json.string(exec.outcome)),
    #("created_at", json.string(exec.created_at)),
  ]

  // Add optional fields only when present (omit rather than null)
  let fields = case exec.suppression_reason {
    "" -> fields
    reason -> [#("suppression_reason", json.string(reason)), ..fields]
  }

  let fields = case exec.user_id {
    0 -> fields
    id -> [#("user_id", json.int(id)), ..fields]
  }

  let fields = case exec.user_email {
    "" -> fields
    email -> [#("user_email", json.string(email)), ..fields]
  }

  json.object(fields)
}

type Totals {
  Totals(evaluated_count: Int, applied_count: Int, suppressed_count: Int)
}

fn calculate_totals(rules: List(rule_metrics_db.RuleMetricsSummary)) -> Totals {
  list.fold(rules, Totals(0, 0, 0), fn(acc, r) {
    Totals(
      evaluated_count: acc.evaluated_count + r.evaluated_count,
      applied_count: acc.applied_count + r.applied_count,
      suppressed_count: acc.suppressed_count + r.suppressed_count,
    )
  })
}

fn calculate_workflow_totals(
  workflows: List(rule_metrics_db.WorkflowMetricsSummary),
) -> Totals {
  list.fold(workflows, Totals(0, 0, 0), fn(acc, w) {
    Totals(
      evaluated_count: acc.evaluated_count + w.evaluated_count,
      applied_count: acc.applied_count + w.applied_count,
      suppressed_count: acc.suppressed_count + w.suppressed_count,
    )
  })
}

fn totals_json(totals: Totals) -> json.Json {
  json.object([
    #("evaluated_count", json.int(totals.evaluated_count)),
    #("applied_count", json.int(totals.applied_count)),
    #("suppressed_count", json.int(totals.suppressed_count)),
  ])
}

fn option_json(opt: Option(a), encoder: fn(a) -> json.Json) -> json.Json {
  case opt {
    Some(value) -> encoder(value)
    None -> json.null()
  }
}
