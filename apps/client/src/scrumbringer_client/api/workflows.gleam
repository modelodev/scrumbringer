//// Workflows API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides workflow, rule, and task template API operations for automation
//// management in the admin interface.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}

import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow, Rule,
  RuleTemplate, TaskTemplate, Workflow,
}

// =============================================================================
// Decoders
// =============================================================================

fn workflow_decoder() -> decode.Decoder(Workflow) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", nullable_int())
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", nullable_string())
  use active <- decode.field("active", decode.bool)
  use rule_count <- decode.field("rule_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Workflow(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    active: active,
    rule_count: rule_count,
    created_by: created_by,
    created_at: created_at,
  ))
}

fn rule_decoder() -> decode.Decoder(Rule) {
  use id <- decode.field("id", decode.int)
  use workflow_id <- decode.field("workflow_id", decode.int)
  use name <- decode.field("name", decode.string)
  use goal <- decode.field("goal", nullable_string())
  use resource_type <- decode.field("resource_type", decode.string)
  use task_type_id <- decode.field("task_type_id", nullable_int())
  use to_state <- decode.field("to_state", decode.string)
  use active <- decode.field("active", decode.bool)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Rule(
    id: id,
    workflow_id: workflow_id,
    name: name,
    goal: goal,
    resource_type: resource_type,
    task_type_id: task_type_id,
    to_state: to_state,
    active: active,
    created_at: created_at,
  ))
}

/// Story 4.9 AC20: Added rules_count field.
fn task_template_decoder() -> decode.Decoder(TaskTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", nullable_int())
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", nullable_string())
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use rules_count <- decode.optional_field("rules_count", 0, decode.int)
  decode.success(TaskTemplate(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    type_id: type_id,
    type_name: type_name,
    priority: priority,
    created_by: created_by,
    created_at: created_at,
    rules_count: rules_count,
  ))
}

fn rule_template_decoder() -> decode.Decoder(RuleTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", nullable_int())
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", nullable_string())
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use execution_order <- decode.field("execution_order", decode.int)
  decode.success(RuleTemplate(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    type_id: type_id,
    type_name: type_name,
    priority: priority,
    created_by: created_by,
    created_at: created_at,
    execution_order: execution_order,
  ))
}

fn nullable_int() -> decode.Decoder(Option(Int)) {
  decode.optional(decode.int)
}

fn nullable_string() -> decode.Decoder(Option(String)) {
  decode.optional(decode.string)
}

// =============================================================================
// Public Payload Decoders (for testing)
// =============================================================================

/// Decoder for workflow wrapped in envelope.
pub fn workflow_payload_decoder() -> decode.Decoder(Workflow) {
  decode.field("workflow", workflow_decoder(), decode.success)
}

/// Decoder for list of workflows.
pub fn workflows_payload_decoder() -> decode.Decoder(List(Workflow)) {
  decode.field("workflows", decode.list(workflow_decoder()), decode.success)
}

/// Decoder for rule wrapped in envelope.
pub fn rule_payload_decoder() -> decode.Decoder(Rule) {
  decode.field("rule", rule_decoder(), decode.success)
}

/// Decoder for list of rules.
pub fn rules_payload_decoder() -> decode.Decoder(List(Rule)) {
  decode.field("rules", decode.list(rule_decoder()), decode.success)
}

/// Decoder for task template wrapped in envelope.
pub fn task_template_payload_decoder() -> decode.Decoder(TaskTemplate) {
  decode.field("task_template", task_template_decoder(), decode.success)
}

/// Decoder for list of task templates.
pub fn task_templates_payload_decoder() -> decode.Decoder(List(TaskTemplate)) {
  decode.field(
    "templates",
    decode.list(task_template_decoder()),
    decode.success,
  )
}

/// Decoder for list of rule templates.
pub fn rule_templates_payload_decoder() -> decode.Decoder(List(RuleTemplate)) {
  decode.field(
    "templates",
    decode.list(rule_template_decoder()),
    decode.success,
  )
}

// =============================================================================
// Workflow API
// =============================================================================

/// List workflows for a project.
pub fn list_project_workflows(
  project_id: Int,
  to_msg: fn(ApiResult(List(Workflow))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("workflows", decode.list(workflow_decoder()), decode.success)
  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
    None,
    decoder,
    to_msg,
  )
}

/// Create workflow in a project.
pub fn create_project_workflow(
  project_id: Int,
  name: String,
  description: String,
  active: Bool,
  to_msg: fn(ApiResult(Workflow)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("active", json.bool(active)),
    ])
  let decoder = decode.field("workflow", workflow_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
    Some(body),
    decoder,
    to_msg,
  )
}

/// Update workflow.
pub fn update_workflow(
  workflow_id: Int,
  name: String,
  description: String,
  active: Bool,
  to_msg: fn(ApiResult(Workflow)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("active", json.int(case active {
        True -> 1
        False -> 0
      })),
    ])
  let decoder = decode.field("workflow", workflow_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/workflows/" <> int.to_string(workflow_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Delete workflow.
pub fn delete_workflow(
  workflow_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil("DELETE",
    "/api/v1/workflows/" <> int.to_string(workflow_id),
    None,
    to_msg,
  )
}

// =============================================================================
// Rule API
// =============================================================================

/// List rules for a workflow.
pub fn list_rules(
  workflow_id: Int,
  to_msg: fn(ApiResult(List(Rule))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("rules", decode.list(rule_decoder()), decode.success)
  core.request(
    "GET",
    "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
    None,
    decoder,
    to_msg,
  )
}

/// Create rule in a workflow.
pub fn create_rule(
  workflow_id: Int,
  name: String,
  goal: String,
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
  active: Bool,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #("resource_type", json.string(resource_type)),
      #("task_type_id", case task_type_id {
        None -> json.null()
        Some(id) -> json.int(id)
      }),
      #("to_state", json.string(to_state)),
      #("active", json.bool(active)),
    ])
  let decoder = decode.field("rule", rule_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
    Some(body),
    decoder,
    to_msg,
  )
}

/// Update rule.
pub fn update_rule(
  rule_id: Int,
  name: String,
  goal: String,
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
  active: Bool,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #("resource_type", json.string(resource_type)),
      #("task_type_id", case task_type_id {
        None -> json.int(-1)
        Some(id) -> json.int(id)
      }),
      #("to_state", json.string(to_state)),
      #("active", json.int(case active {
        True -> 1
        False -> 0
      })),
    ])
  let decoder = decode.field("rule", rule_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/rules/" <> int.to_string(rule_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Delete rule.
pub fn delete_rule(
  rule_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil("DELETE", "/api/v1/rules/" <> int.to_string(rule_id), None, to_msg)
}

/// Attach template to rule.
pub fn attach_template(
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
  to_msg: fn(ApiResult(List(RuleTemplate))) -> msg,
) -> Effect(msg) {
  let body = json.object([#("execution_order", json.int(execution_order))])
  let decoder =
    decode.field(
      "templates",
      decode.list(rule_template_decoder()),
      decode.success,
    )
  core.request(
    "POST",
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/templates/"
      <> int.to_string(template_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Detach template from rule.
pub fn detach_template(
  rule_id: Int,
  template_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/templates/"
      <> int.to_string(template_id),
    None,
    to_msg,
  )
}

// =============================================================================
// TaskTemplate API
// =============================================================================

/// List task templates for a project.
pub fn list_project_templates(
  project_id: Int,
  to_msg: fn(ApiResult(List(TaskTemplate))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "templates",
      decode.list(task_template_decoder()),
      decode.success,
    )
  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
    None,
    decoder,
    to_msg,
  )
}

/// Create task template in a project.
pub fn create_project_template(
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  to_msg: fn(ApiResult(TaskTemplate)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("type_id", json.int(type_id)),
      #("priority", json.int(priority)),
    ])
  let decoder =
    decode.field("task_template", task_template_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
    Some(body),
    decoder,
    to_msg,
  )
}

/// Update task template.
pub fn update_template(
  template_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  to_msg: fn(ApiResult(TaskTemplate)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("type_id", json.int(type_id)),
      #("priority", json.int(priority)),
    ])
  let decoder =
    decode.field("task_template", task_template_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/task-templates/" <> int.to_string(template_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Delete task template.
pub fn delete_template(
  template_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/task-templates/" <> int.to_string(template_id),
    None,
    to_msg,
  )
}

// =============================================================================
// Rule Metrics API
// =============================================================================

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
  WorkflowMetrics(workflow_id: Int, workflow_name: String, rules: List(RuleMetricsSummary))
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

pub fn workflow_metrics_decoder() -> decode.Decoder(WorkflowMetrics) {
  use workflow_id <- decode.field("workflow_id", decode.int)
  use workflow_name <- decode.field("workflow_name", decode.string)
  use rules <- decode.field("rules", decode.list(rule_metrics_summary_decoder()))
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
  // Note: core.request already unwraps the { data: ... } envelope
  core.request(
    "GET",
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

pub fn org_workflow_metrics_summary_decoder() -> decode.Decoder(OrgWorkflowMetricsSummary) {
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

/// Fetch org-wide rule metrics.
pub fn get_org_rule_metrics(
  from: String,
  to: String,
  to_msg: fn(ApiResult(List(OrgWorkflowMetricsSummary))) -> msg,
) -> Effect(msg) {
  let decoder = decode.field(
    "workflows",
    decode.list(org_workflow_metrics_summary_decoder()),
    decode.success,
  )
  core.request(
    "GET",
    "/api/v1/org/rule-metrics?from=" <> from <> "&to=" <> to,
    None,
    decoder,
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
  let decoder = decode.field(
    "workflows",
    decode.list(org_workflow_metrics_summary_decoder()),
    decode.success,
  )
  core.request(
    "GET",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/rule-metrics?from="
      <> from
      <> "&to="
      <> to,
    None,
    decoder,
    to_msg,
  )
}

// =============================================================================
// Detailed Rule Metrics (with suppression breakdown)
// =============================================================================

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
    "GET",
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

// =============================================================================
// Rule Executions (drill-down)
// =============================================================================

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

pub fn rule_executions_response_decoder() -> decode.Decoder(RuleExecutionsResponse) {
  use rule_id <- decode.field("rule_id", decode.int)
  use executions <- decode.field("executions", decode.list(rule_execution_decoder()))
  use pagination <- decode.field("pagination", pagination_decoder())
  decode.success(RuleExecutionsResponse(
    rule_id: rule_id,
    executions: executions,
    pagination: pagination,
  ))
}

/// Fetch paginated executions for a rule (drill-down).
pub fn get_rule_executions(
  rule_id: Int,
  from: String,
  to: String,
  limit: Int,
  offset: Int,
  to_msg: fn(ApiResult(RuleExecutionsResponse)) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
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
