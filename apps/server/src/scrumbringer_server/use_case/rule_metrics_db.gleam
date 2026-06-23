//// Database access layer for rule metrics.
////
//// ## Mission
////
//// Provide query access to rule execution metrics.
////
//// ## Responsibilities
////
//// - Fetch aggregated rule metrics
//// - Fetch execution drill-down details
//// - Provide org/project summary views
////
//// ## Non-responsibilities
////
//// - HTTP response formatting (see `http/rule_metrics.gleam`)
//// - Rule evaluation (see `use_case/rules_engine.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for query execution

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field

// =============================================================================
// Types
// =============================================================================

/// Aggregated metrics for a rule.
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

/// Detailed metrics for a rule, including suppression breakdown.
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

/// Single rule execution record for drill-down views.
pub type RuleExecution {
  RuleExecution(
    id: Int,
    task_id: Option(Int),
    card_id: Option(Int),
    outcome: String,
    suppression_reason: String,
    user_id: Int,
    user_email: String,
    template_id: Option(Int),
    template_version: Option(Int),
    created_task_id: Option(Int),
    created_at: String,
  )
}

/// Business execution record for a project-level automations history view.
pub type ProjectRuleExecution {
  ProjectRuleExecution(
    id: Int,
    workflow_id: Int,
    workflow_name: String,
    rule_id: Int,
    rule_name: String,
    task_id: Option(Int),
    task_title: String,
    card_id: Option(Int),
    card_title: String,
    outcome: String,
    suppression_reason: String,
    user_id: Int,
    user_email: String,
    template_id: Option(Int),
    template_name: String,
    template_version: Option(Int),
    created_task_id: Option(Int),
    created_task_title: String,
    created_at: String,
  )
}

/// Aggregated metrics summary for a workflow.
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

fn rule_metrics_summary_from_row(
  row: sql.RuleMetricsByWorkflowRow,
) -> RuleMetricsSummary {
  RuleMetricsSummary(
    rule_id: row.rule_id,
    rule_name: row.rule_name,
    active: row.active,
    evaluated_count: row.evaluated_count,
    applied_count: row.applied_count,
    suppressed_count: row.suppressed_count,
  )
}

fn rule_metrics_detailed_from_row(
  row: sql.RuleMetricsByRuleRow,
) -> RuleMetricsDetailed {
  RuleMetricsDetailed(
    rule_id: row.rule_id,
    rule_name: row.rule_name,
    evaluated_count: row.evaluated_count,
    applied_count: row.applied_count,
    suppressed_count: row.suppressed_count,
    suppressed_idempotent: row.suppressed_idempotent,
    suppressed_not_user: row.suppressed_not_user,
    suppressed_not_matching: row.suppressed_not_matching,
    suppressed_inactive: row.suppressed_inactive,
  )
}

fn rule_execution_from_row(row: sql.RuleExecutionsListRow) -> RuleExecution {
  RuleExecution(
    id: row.id,
    task_id: option_helpers.int_to_option(row.task_id),
    card_id: option_helpers.int_to_option(row.card_id),
    outcome: row.outcome,
    suppression_reason: row.suppression_reason,
    user_id: row.user_id,
    user_email: row.user_email,
    template_id: option_helpers.int_to_option(row.template_id),
    template_version: option_helpers.int_to_option(row.template_version),
    created_task_id: option_helpers.int_to_option(row.created_task_id),
    created_at: row.created_at,
  )
}

fn project_rule_execution_from_row(
  row: sql.RuleExecutionsListForProjectRow,
) -> ProjectRuleExecution {
  ProjectRuleExecution(
    id: row.id,
    workflow_id: row.workflow_id,
    workflow_name: row.workflow_name,
    rule_id: row.rule_id,
    rule_name: row.rule_name,
    task_id: option_helpers.int_to_option(row.task_id),
    task_title: row.task_title,
    card_id: option_helpers.int_to_option(row.card_id),
    card_title: row.card_title,
    outcome: row.outcome,
    suppression_reason: row.suppression_reason,
    user_id: row.user_id,
    user_email: row.user_email,
    template_id: option_helpers.int_to_option(row.template_id),
    template_name: row.template_name,
    template_version: option_helpers.int_to_option(row.template_version),
    created_task_id: option_helpers.int_to_option(row.created_task_id),
    created_task_title: row.created_task_title,
    created_at: row.created_at,
  )
}

fn workflow_metrics_summary_from_fields(
  workflow_id: Int,
  workflow_name: String,
  project_id: Option(Int),
  rule_count: Int,
  evaluated_count: Int,
  applied_count: Int,
  suppressed_count: Int,
) -> WorkflowMetricsSummary {
  WorkflowMetricsSummary(
    workflow_id: workflow_id,
    workflow_name: workflow_name,
    project_id: project_id,
    rule_count: rule_count,
    evaluated_count: evaluated_count,
    applied_count: applied_count,
    suppressed_count: suppressed_count,
  )
}

fn workflow_metrics_summary_from_org_row(
  row: sql.RuleMetricsOrgSummaryRow,
) -> WorkflowMetricsSummary {
  workflow_metrics_summary_from_fields(
    row.workflow_id,
    row.workflow_name,
    option_helpers.int_to_option(row.project_id),
    row.rule_count,
    row.evaluated_count,
    row.applied_count,
    row.suppressed_count,
  )
}

fn workflow_metrics_summary_from_project_row(
  row: sql.RuleMetricsProjectSummaryRow,
  project_id: Int,
) -> WorkflowMetricsSummary {
  workflow_metrics_summary_from_fields(
    row.workflow_id,
    row.workflow_name,
    Some(project_id),
    row.rule_count,
    row.evaluated_count,
    row.applied_count,
    row.suppressed_count,
  )
}

// =============================================================================
// Public API
// =============================================================================

/// Get aggregated metrics for all rules in a workflow.
///
/// Example:
///   get_workflow_metrics(db, workflow_id, from, to)
pub fn get_workflow_metrics(
  db: pog.Connection,
  workflow_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(List(RuleMetricsSummary), pog.QueryError) {
  sql.rule_metrics_by_workflow(db, workflow_id, from, to)
  |> result.map(fn(returned) {
    returned.rows
    |> list.map(rule_metrics_summary_from_row)
  })
}

/// Get detailed metrics for a single rule with suppression breakdown.
///
/// Example:
///   get_rule_metrics(db, rule_id, from, to)
pub fn get_rule_metrics(
  db: pog.Connection,
  rule_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(Option(RuleMetricsDetailed), pog.QueryError) {
  sql.rule_metrics_by_rule(db, rule_id, from, to)
  |> result.map(fn(returned) {
    case returned.rows {
      [row, ..] -> Some(rule_metrics_detailed_from_row(row))
      [] -> None
    }
  })
}

/// Get paginated list of executions for a rule (drill-down).
///
/// Example:
///   list_rule_executions(db, rule_id, from, to, limit, offset)
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
    |> list.map(rule_execution_from_row)
  })
}

/// Count total executions for a rule (for pagination).
///
/// Example:
///   count_rule_executions(db, rule_id, from, to)
pub fn count_rule_executions(
  db: pog.Connection,
  rule_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(Int, pog.QueryError) {
  use returned <- result.try(sql.rule_executions_count(db, rule_id, from, to))
  use row <- result.try(persisted_field.query_row(returned.rows))
  Ok(row.total)
}

/// Get paginated business executions visible in a project.
///
/// Example:
///   list_project_rule_executions(db, project_id, from, to, limit, offset)
pub fn list_project_rule_executions(
  db: pog.Connection,
  project_id: Int,
  from: Timestamp,
  to: Timestamp,
  limit: Int,
  offset: Int,
) -> Result(List(ProjectRuleExecution), pog.QueryError) {
  sql.rule_executions_list_for_project(db, project_id, from, to, limit, offset)
  |> result.map(fn(returned) {
    returned.rows
    |> list.map(project_rule_execution_from_row)
  })
}

/// Count business executions visible in a project.
///
/// Example:
///   count_project_rule_executions(db, project_id, from, to)
pub fn count_project_rule_executions(
  db: pog.Connection,
  project_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(Int, pog.QueryError) {
  use returned <- result.try(sql.rule_executions_count_for_project(
    db,
    project_id,
    from,
    to,
  ))
  use row <- result.try(persisted_field.query_row(returned.rows))
  Ok(row.total)
}

/// Get org-wide rule metrics summary.
///
/// Example:
///   get_org_metrics_summary(db, org_id, from, to)
pub fn get_org_metrics_summary(
  db: pog.Connection,
  org_id: Int,
  from: Timestamp,
  to: Timestamp,
) -> Result(List(WorkflowMetricsSummary), pog.QueryError) {
  sql.rule_metrics_org_summary(db, org_id, from, to)
  |> result.map(fn(returned) {
    returned.rows
    |> list.map(workflow_metrics_summary_from_org_row)
  })
}

/// Get project-scoped rule metrics summary.
///
/// Example:
///   get_project_metrics_summary(db, project_id, from, to)
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
      workflow_metrics_summary_from_project_row(row, project_id)
    })
  })
}
