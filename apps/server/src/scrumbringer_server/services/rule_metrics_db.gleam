////
//// Database access layer for rule metrics.
////

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql

// =============================================================================
// Types
// =============================================================================

pub type RuleMetricsSummary {
  RuleMetricsSummary(
    rule_id: Int,
    rule_name: String,
    active: Bool,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
  )
}

pub type RuleMetricsDetailed {
  RuleMetricsDetailed(
    rule_id: Int,
    rule_name: String,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
    suppressed_idempotent: Int,
    suppressed_not_user: Int,
    suppressed_not_matching: Int,
    suppressed_inactive: Int,
  )
}

pub type RuleExecution {
  RuleExecution(
    id: Int,
    origin_type: String,
    origin_id: Int,
    outcome: String,
    suppression_reason: String,
    user_id: Int,
    user_email: String,
    created_at: String,
  )
}

pub type WorkflowMetricsSummary {
  WorkflowMetricsSummary(
    workflow_id: Int,
    workflow_name: String,
    project_id: Option(Int),
    rule_count: Int,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
  )
}

// =============================================================================
// Public API
// =============================================================================

/// Get aggregated metrics for all rules in a workflow.
pub fn get_workflow_metrics(
  db: pog.Connection,
  workflow_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(List(RuleMetricsSummary), pog.QueryError) {
  sql.rule_metrics_by_workflow(db, workflow_id, from, to)
  |> result.map(fn(returned) {
    returned.rows
    |> list.map(fn(row) {
      RuleMetricsSummary(
        rule_id: row.rule_id,
        rule_name: row.rule_name,
        active: row.active,
        evaluated_count: row.evaluated_count,
        applied_count: row.applied_count,
        suppressed_count: row.suppressed_count,
      )
    })
  })
}

/// Get detailed metrics for a single rule with suppression breakdown.
pub fn get_rule_metrics(
  db: pog.Connection,
  rule_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(Option(RuleMetricsDetailed), pog.QueryError) {
  sql.rule_metrics_by_rule(db, rule_id, from, to)
  |> result.map(fn(returned) {
    case returned.rows {
      [row, ..] ->
        Some(RuleMetricsDetailed(
          rule_id: row.rule_id,
          rule_name: row.rule_name,
          evaluated_count: row.evaluated_count,
          applied_count: row.applied_count,
          suppressed_count: row.suppressed_count,
          suppressed_idempotent: row.suppressed_idempotent,
          suppressed_not_user: row.suppressed_not_user,
          suppressed_not_matching: row.suppressed_not_matching,
          suppressed_inactive: row.suppressed_inactive,
        ))
      [] -> None
    }
  })
}

/// Get paginated list of executions for a rule (drill-down).
pub fn list_rule_executions(
  db: pog.Connection,
  rule_id: Int,
  from: Timestamp,
  to: Timestamp,
  limit: Int,
  offset: Int,
) -> Result(List(RuleExecution), pog.QueryError) {
  sql.rule_executions_list(db, rule_id, from, to, limit, offset)
  |> result.map(fn(returned) {
    returned.rows
    |> list.map(fn(row) {
      RuleExecution(
        id: row.id,
        origin_type: row.origin_type,
        origin_id: row.origin_id,
        outcome: row.outcome,
        suppression_reason: row.suppression_reason,
        user_id: row.user_id,
        user_email: row.user_email,
        created_at: row.created_at,
      )
    })
  })
}

/// Count total executions for a rule (for pagination).
pub fn count_rule_executions(
  db: pog.Connection,
  rule_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(Int, pog.QueryError) {
  sql.rule_executions_count(db, rule_id, from, to)
  |> result.map(fn(returned) {
    case returned.rows {
      [row, ..] -> row.total
      [] -> 0
    }
  })
}

/// Get org-wide rule metrics summary.
pub fn get_org_metrics_summary(
  db: pog.Connection,
  org_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(List(WorkflowMetricsSummary), pog.QueryError) {
  sql.rule_metrics_org_summary(db, org_id, from, to)
  |> result.map(fn(returned) {
    returned.rows
    |> list.map(fn(row) {
      WorkflowMetricsSummary(
        workflow_id: row.workflow_id,
        workflow_name: row.workflow_name,
        project_id: option_helpers.int_to_option(row.project_id),
        rule_count: row.rule_count,
        evaluated_count: row.evaluated_count,
        applied_count: row.applied_count,
        suppressed_count: row.suppressed_count,
      )
    })
  })
}

/// Get project-scoped rule metrics summary.
pub fn get_project_metrics_summary(
  db: pog.Connection,
  project_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(List(WorkflowMetricsSummary), pog.QueryError) {
  sql.rule_metrics_project_summary(db, project_id, from, to)
  |> result.map(fn(returned) {
    returned.rows
    |> list.map(fn(row) {
      WorkflowMetricsSummary(
        workflow_id: row.workflow_id,
        workflow_name: row.workflow_name,
        project_id: Some(project_id),
        rule_count: row.rule_count,
        evaluated_count: row.evaluated_count,
        applied_count: row.applied_count,
        suppressed_count: row.suppressed_count,
      )
    })
  })
}
