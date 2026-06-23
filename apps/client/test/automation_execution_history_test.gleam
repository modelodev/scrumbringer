import gleam/int
import gleam/option
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/features/automations/execution_history
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn workflow_summary() -> api_rule_metrics.OrgWorkflowMetricsSummary {
  api_rule_metrics.OrgWorkflowMetricsSummary(
    workflow_id: 11,
    workflow_name: "Escalation workflow",
    project_id: 3,
    rule_count: 2,
    evaluated_count: 9,
    applied_count: 6,
    suppressed_count: 3,
  )
}

fn rule_summary() -> api_rule_metrics.RuleMetricsSummary {
  api_rule_metrics.RuleMetricsSummary(
    rule_id: 22,
    rule_name: "Escalate blocked work",
    evaluated_count: 5,
    applied_count: 2,
    suppressed_count: 3,
  )
}

fn workflow_metrics() -> api_rule_metrics.WorkflowMetrics {
  api_rule_metrics.WorkflowMetrics(
    workflow_id: 11,
    workflow_name: "Escalation workflow",
    rules: [rule_summary()],
  )
}

fn rule_details() -> api_rule_metrics.RuleMetricsDetailed {
  api_rule_metrics.RuleMetricsDetailed(
    rule_id: 22,
    rule_name: "Escalate blocked work",
    evaluated_count: 5,
    applied_count: 2,
    suppressed_count: 3,
    suppression_breakdown: api_rule_metrics.SuppressionBreakdown(
      idempotent: 1,
      not_user_triggered: 1,
      not_matching: 1,
      inactive: 0,
    ),
  )
}

fn execution() -> api_rule_metrics.RuleExecution {
  api_rule_metrics.RuleExecution(
    id: 101,
    task_id: option.Some(42),
    card_id: option.None,
    outcome: "applied",
    suppression_reason: "",
    user_id: 7,
    user_email: "member@example.com",
    template_id: option.Some(12),
    template_version: option.Some(3),
    created_task_id: option.Some(43),
    created_at: "2026-06-08T10:00:00Z",
  )
}

fn ignored_execution() -> api_rule_metrics.RuleExecution {
  api_rule_metrics.RuleExecution(
    id: 102,
    task_id: option.Some(42),
    card_id: option.None,
    outcome: "suppressed",
    suppression_reason: "idempotent",
    user_id: 7,
    user_email: "member@example.com",
    template_id: option.None,
    template_version: option.None,
    created_task_id: option.None,
    created_at: "2026-06-08T10:01:00Z",
  )
}

fn executions_response() -> api_rule_metrics.RuleExecutionsResponse {
  api_rule_metrics.RuleExecutionsResponse(
    rule_id: 22,
    executions: [execution(), ignored_execution()],
    pagination: api_rule_metrics.Pagination(limit: 20, offset: 20, total: 45),
  )
}

fn config() -> execution_history.Config(String) {
  execution_history.Config(
    locale: locale.En,
    model: admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics: Loaded([workflow_summary()]),
      admin_rule_metrics_from: "2026-06-01",
      admin_rule_metrics_to: "2026-06-08",
    ),
    quick_ranges: [
      execution_history.QuickRange(
        label: "7 days",
        from: "2026-06-01",
        to: "2026-06-08",
        on_clicked: "range-7",
      ),
    ],
    on_from_changed: fn(value) { "from-" <> value },
    on_to_changed: fn(value) { "to-" <> value },
    on_workflow_expanded: fn(id) { "workflow-" <> int.to_string(id) },
    on_drilldown_clicked: fn(id) { "drilldown-" <> int.to_string(id) },
    on_drilldown_closed: "drilldown-closed",
    on_exec_page_changed: fn(offset) { "page-" <> int.to_string(offset) },
  )
}

pub fn automation_execution_history_renders_from_config_without_root_model_test() {
  let html =
    execution_history.view(config())
    |> element.to_document_string

  assert_contains(html, "Review automation executions")
  assert_contains(html, "filter-bar automation-executions-filters")
  assert_contains(html, "data-testid=\"automation-executions-filter-bar\"")
  assert_contains(html, "Escalation workflow")
  assert_contains(html, "Created")
  assert_contains(html, "Ignored")
  assert_contains(html, "9")
  assert_contains(html, "6")
  assert_contains(html, "3")
  assert_contains(html, "btn-chip-active")
  assert_not_contains(html, "Suppressed")
  assert_not_contains(html, "admin-card")
  assert_not_contains(html, "section-header")
}

pub fn automation_execution_history_renders_empty_state_without_root_model_test() {
  let html =
    execution_history.view(
      execution_history.Config(
        ..config(),
        model: admin_metrics.Model(
          ..config().model,
          admin_rule_metrics: Loaded([]),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "No automation executions found in the selected range.")
}

pub fn automation_execution_history_detail_action_uses_semantic_button_test() {
  let html =
    execution_history.view(
      execution_history.Config(
        ..config(),
        model: admin_metrics.Model(
          ..config().model,
          admin_rule_metrics_expanded_workflow: option.Some(11),
          admin_rule_metrics_workflow_details: Loaded(workflow_metrics()),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Escalate blocked work")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "btn-xs")
  assert_contains(html, "aria-label=\"View Details\"")
}

pub fn automation_execution_history_pagination_uses_semantic_accessible_buttons_test() {
  let html =
    execution_history.view(
      execution_history.Config(
        ..config(),
        model: admin_metrics.Model(
          ..config().model,
          admin_rule_metrics_drilldown_rule_id: option.Some(22),
          admin_rule_metrics_rule_details: Loaded(rule_details()),
          admin_rule_metrics_executions: Loaded(executions_response()),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "2 / 3")
  assert_contains(html, "btn-close")
  assert_contains(html, "aria-label=\"Close\"")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "aria-label=\"First page\"")
  assert_contains(html, "aria-label=\"Previous page\"")
  assert_contains(html, "aria-label=\"Next page\"")
  assert_contains(html, "aria-label=\"Last page\"")
  assert_contains(html, "data-testid=\"automation-execution-row\"")
  assert_contains(html, "Created")
  assert_contains(html, "Ignored (idempotent)")
  assert_not_contains(html, "Suppressed")
}
