//// Rule metrics API functions for automation workflows.

import gleam/dynamic/decode
import gleam/int
import gleam/option.{None}

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import scrumbringer_client/api/core

/// Rule metrics summary for a single rule.
pub type RuleMetricsSummary {
  RuleMetricsSummary(
    rule_id: Int,
    rule_name: String,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
  )
}

/// Workflow metrics containing rule summaries.
pub type WorkflowMetrics {
  WorkflowMetrics(
    workflow_id: Int,
    workflow_name: String,
    rules: List(RuleMetricsSummary),
  )
}

fn rule_metrics_summary_decoder() -> decode.Decoder(RuleMetricsSummary) {
  use rule_id <- decode.field("rule_id", decode.int)
  use rule_name <- decode.field("rule_name", decode.string)
  use evaluated_count <- decode.field("evaluated_count", decode.int)
  use applied_count <- decode.field("applied_count", decode.int)
  use suppressed_count <- decode.field("suppressed_count", decode.int)
  decode.success(RuleMetricsSummary(
    rule_id: rule_id,
    rule_name: rule_name,
    evaluated_count: evaluated_count,
    applied_count: applied_count,
    suppressed_count: suppressed_count,
  ))
}

/// Provides workflow metrics decoder.
pub fn workflow_metrics_decoder() -> decode.Decoder(WorkflowMetrics) {
  use workflow_id <- decode.field("workflow_id", decode.int)
  use workflow_name <- decode.field("workflow_name", decode.string)
  use rules <- decode.field(
    "rules",
    decode.list(rule_metrics_summary_decoder()),
  )
  decode.success(WorkflowMetrics(
    workflow_id: workflow_id,
    workflow_name: workflow_name,
    rules: rules,
  ))
}

/// Fetch metrics for a workflow.
pub fn get_workflow_metrics(
  workflow_id: Int,
  to_msg: fn(ApiResult(WorkflowMetrics)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/metrics",
    None,
    workflow_metrics_decoder(),
    to_msg,
  )
}

/// Org-level workflow metrics summary.
pub type OrgWorkflowMetricsSummary {
  OrgWorkflowMetricsSummary(
    workflow_id: Int,
    workflow_name: String,
    project_id: Int,
    rule_count: Int,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
  )
}

/// Provides org workflow metrics summary decoder.
pub fn org_workflow_metrics_summary_decoder() -> decode.Decoder(
  OrgWorkflowMetricsSummary,
) {
  use workflow_id <- decode.field("workflow_id", decode.int)
  use workflow_name <- decode.field("workflow_name", decode.string)
  use project_id <- decode.field("project_id", decode.int)
  use rule_count <- decode.field("rule_count", decode.int)
  use evaluated_count <- decode.field("evaluated_count", decode.int)
  use applied_count <- decode.field("applied_count", decode.int)
  use suppressed_count <- decode.field("suppressed_count", decode.int)
  decode.success(OrgWorkflowMetricsSummary(
    workflow_id: workflow_id,
    workflow_name: workflow_name,
    project_id: project_id,
    rule_count: rule_count,
    evaluated_count: evaluated_count,
    applied_count: applied_count,
    suppressed_count: suppressed_count,
  ))
}

fn org_rule_metrics_decoder() -> decode.Decoder(List(OrgWorkflowMetricsSummary)) {
  decode.field(
    "workflows",
    decode.list(org_workflow_metrics_summary_decoder()),
    decode.success,
  )
}

/// Fetch org-wide rule metrics.
pub fn get_org_rule_metrics(
  from: String,
  to: String,
  to_msg: fn(ApiResult(List(OrgWorkflowMetricsSummary))) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/org/rule-metrics?from=" <> from <> "&to=" <> to,
    None,
    org_rule_metrics_decoder(),
    to_msg,
  )
}

/// Fetch project-scoped rule metrics.
pub fn get_project_rule_metrics(
  project_id: Int,
  from: String,
  to: String,
  to_msg: fn(ApiResult(List(OrgWorkflowMetricsSummary))) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/rule-metrics?from="
      <> from
      <> "&to="
      <> to,
    None,
    org_rule_metrics_decoder(),
    to_msg,
  )
}

/// Detailed rule metrics with suppression breakdown.
pub type RuleMetricsDetailed {
  RuleMetricsDetailed(
    rule_id: Int,
    rule_name: String,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
    suppression_breakdown: SuppressionBreakdown,
  )
}

/// Suppression reason breakdown.
pub type SuppressionBreakdown {
  SuppressionBreakdown(
    idempotent: Int,
    not_user_triggered: Int,
    not_matching: Int,
    inactive: Int,
  )
}

fn suppression_breakdown_decoder() -> decode.Decoder(SuppressionBreakdown) {
  use idempotent <- decode.field("idempotent", decode.int)
  use not_user_triggered <- decode.field("not_user_triggered", decode.int)
  use not_matching <- decode.field("not_matching", decode.int)
  use inactive <- decode.field("inactive", decode.int)
  decode.success(SuppressionBreakdown(
    idempotent: idempotent,
    not_user_triggered: not_user_triggered,
    not_matching: not_matching,
    inactive: inactive,
  ))
}

/// Provides rule metrics detailed decoder.
pub fn rule_metrics_detailed_decoder() -> decode.Decoder(RuleMetricsDetailed) {
  use rule_id <- decode.field("rule_id", decode.int)
  use rule_name <- decode.field("rule_name", decode.string)
  use evaluated_count <- decode.field("evaluated_count", decode.int)
  use applied_count <- decode.field("applied_count", decode.int)
  use suppressed_count <- decode.field("suppressed_count", decode.int)
  use suppression_breakdown <- decode.field(
    "suppression_breakdown",
    suppression_breakdown_decoder(),
  )
  decode.success(RuleMetricsDetailed(
    rule_id: rule_id,
    rule_name: rule_name,
    evaluated_count: evaluated_count,
    applied_count: applied_count,
    suppressed_count: suppressed_count,
    suppression_breakdown: suppression_breakdown,
  ))
}

/// Fetch detailed metrics for a single rule.
pub fn get_rule_metrics_detailed(
  rule_id: Int,
  from: String,
  to: String,
  to_msg: fn(ApiResult(RuleMetricsDetailed)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/metrics?from="
      <> from
      <> "&to="
      <> to,
    None,
    rule_metrics_detailed_decoder(),
    to_msg,
  )
}

/// Single rule execution record.
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

/// Pagination info.
pub type Pagination {
  Pagination(limit: Int, offset: Int, total: Int)
}

/// Rule executions response with pagination.
pub type RuleExecutionsResponse {
  RuleExecutionsResponse(
    rule_id: Int,
    executions: List(RuleExecution),
    pagination: Pagination,
  )
}

fn rule_execution_decoder() -> decode.Decoder(RuleExecution) {
  use id <- decode.field("id", decode.int)
  use origin_type <- decode.field("origin_type", decode.string)
  use origin_id <- decode.field("origin_id", decode.int)
  use outcome <- decode.field("outcome", decode.string)
  use suppression_reason <- decode.optional_field(
    "suppression_reason",
    "",
    decode.string,
  )
  use user_id <- decode.optional_field("user_id", 0, decode.int)
  use user_email <- decode.optional_field("user_email", "", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(RuleExecution(
    id: id,
    origin_type: origin_type,
    origin_id: origin_id,
    outcome: outcome,
    suppression_reason: suppression_reason,
    user_id: user_id,
    user_email: user_email,
    created_at: created_at,
  ))
}

fn pagination_decoder() -> decode.Decoder(Pagination) {
  use limit <- decode.field("limit", decode.int)
  use offset <- decode.field("offset", decode.int)
  use total <- decode.field("total", decode.int)
  decode.success(Pagination(limit: limit, offset: offset, total: total))
}

/// Provides rule executions response decoder.
pub fn rule_executions_response_decoder() -> decode.Decoder(
  RuleExecutionsResponse,
) {
  use rule_id <- decode.field("rule_id", decode.int)
  use executions <- decode.field(
    "executions",
    decode.list(rule_execution_decoder()),
  )
  use pagination <- decode.field("pagination", pagination_decoder())
  decode.success(RuleExecutionsResponse(
    rule_id: rule_id,
    executions: executions,
    pagination: pagination,
  ))
}

/// Fetch paginated executions for a rule.
pub fn get_rule_executions(
  rule_id: Int,
  from: String,
  to: String,
  limit: Int,
  offset: Int,
  to_msg: fn(ApiResult(RuleExecutionsResponse)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/executions?from="
      <> from
      <> "&to="
      <> to
      <> "&limit="
      <> int.to_string(limit)
      <> "&offset="
      <> int.to_string(offset),
    None,
    rule_executions_response_decoder(),
    to_msg,
  )
}
