//// JSON presenters for rule metrics HTTP responses.

import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import scrumbringer_server/use_case/rule_metrics_db

type Totals {
  Totals(evaluated_count: Int, applied_count: Int, suppressed_count: Int)
}

pub fn workflow_metrics_json(
  workflow_id: Int,
  workflow_name: String,
  from: Timestamp,
  to: Timestamp,
  rules: List(rule_metrics_db.RuleMetricsSummary),
) -> json.Json {
  json.object([
    #("workflow_id", json.int(workflow_id)),
    #("workflow_name", json.string(workflow_name)),
    #("from", json.string(timestamp_to_string(from))),
    #("to", json.string(timestamp_to_string(to))),
    #("rules", json.array(rules, of: rule_metrics_summary_json)),
    #("totals", totals_json(calculate_rule_totals(rules))),
  ])
}

pub fn rule_metrics_json(
  metrics: rule_metrics_db.RuleMetricsDetailed,
  from: Timestamp,
  to: Timestamp,
) -> json.Json {
  json.object([
    #("rule_id", json.int(metrics.rule_id)),
    #("rule_name", json.string(metrics.rule_name)),
    #("from", json.string(timestamp_to_string(from))),
    #("to", json.string(timestamp_to_string(to))),
    #("evaluated_count", json.int(metrics.evaluated_count)),
    #("applied_count", json.int(metrics.applied_count)),
    #("suppressed_count", json.int(metrics.suppressed_count)),
    #(
      "suppression_breakdown",
      json.object([
        #("idempotent", json.int(metrics.suppressed_idempotent)),
        #("not_user_triggered", json.int(metrics.suppressed_not_user)),
        #("not_matching", json.int(metrics.suppressed_not_matching)),
        #("inactive", json.int(metrics.suppressed_inactive)),
      ]),
    ),
  ])
}

pub fn rule_executions_json(
  rule_id: Int,
  executions: List(rule_metrics_db.RuleExecution),
  limit: Int,
  offset: Int,
  total: Int,
) -> json.Json {
  json.object([
    #("rule_id", json.int(rule_id)),
    #("executions", json.array(executions, of: execution_json)),
    #(
      "pagination",
      json.object([
        #("limit", json.int(limit)),
        #("offset", json.int(offset)),
        #("total", json.int(total)),
      ]),
    ),
  ])
}

pub fn org_metrics_json(
  from: Timestamp,
  to: Timestamp,
  workflows: List(rule_metrics_db.WorkflowMetricsSummary),
) -> json.Json {
  workflows_metrics_json(from, to, workflows, [])
}

pub fn project_metrics_json(
  project_id: Int,
  from: Timestamp,
  to: Timestamp,
  workflows: List(rule_metrics_db.WorkflowMetricsSummary),
) -> json.Json {
  workflows_metrics_json(from, to, workflows, [
    #("project_id", json.int(project_id)),
  ])
}

fn workflows_metrics_json(
  from: Timestamp,
  to: Timestamp,
  workflows: List(rule_metrics_db.WorkflowMetricsSummary),
  extra_fields: List(#(String, json.Json)),
) -> json.Json {
  json.object(
    list.append(extra_fields, [
      #("from", json.string(timestamp_to_string(from))),
      #("to", json.string(timestamp_to_string(to))),
      #("workflows", json.array(workflows, of: workflow_summary_json)),
      #("totals", totals_json(calculate_workflow_totals(workflows))),
    ]),
  )
}

fn rule_metrics_summary_json(
  metrics: rule_metrics_db.RuleMetricsSummary,
) -> json.Json {
  json.object([
    #("rule_id", json.int(metrics.rule_id)),
    #("rule_name", json.string(metrics.rule_name)),
    #("active", json.bool(metrics.active)),
    #("evaluated_count", json.int(metrics.evaluated_count)),
    #("applied_count", json.int(metrics.applied_count)),
    #("suppressed_count", json.int(metrics.suppressed_count)),
  ])
}

fn workflow_summary_json(
  summary: rule_metrics_db.WorkflowMetricsSummary,
) -> json.Json {
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
  let fields = [
    #("id", json.int(exec.id)),
    #("outcome", json.string(exec.outcome)),
    #("created_at", json.string(exec.created_at)),
  ]

  let fields = case exec.task_id {
    None -> fields
    Some(id) -> [#("task_id", json.int(id)), ..fields]
  }

  let fields = case exec.card_id {
    None -> fields
    Some(id) -> [#("card_id", json.int(id)), ..fields]
  }

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

fn calculate_rule_totals(
  rules: List(rule_metrics_db.RuleMetricsSummary),
) -> Totals {
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

fn timestamp_to_string(ts: Timestamp) -> String {
  timestamp.to_rfc3339(ts, duration.seconds(0))
}
