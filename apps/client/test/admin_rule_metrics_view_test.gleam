import gleam/int
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/features/admin/rule_metrics_view
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
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

fn config() -> rule_metrics_view.Config(String) {
  rule_metrics_view.Config(
    locale: locale.En,
    model: admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics: Loaded([workflow_summary()]),
      admin_rule_metrics_from: "2026-06-01",
      admin_rule_metrics_to: "2026-06-08",
    ),
    quick_ranges: [
      rule_metrics_view.QuickRange(
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

pub fn rule_metrics_view_renders_from_config_without_root_model_test() {
  let html =
    rule_metrics_view.view_rule_metrics(config())
    |> element.to_document_string

  assert_contains(html, "Rule Metrics")
  assert_contains(html, "Escalation workflow")
  assert_contains(html, "9")
  assert_contains(html, "6")
  assert_contains(html, "3")
  assert_contains(html, "btn-chip-active")
}

pub fn rule_metrics_view_renders_empty_state_without_root_model_test() {
  let html =
    rule_metrics_view.view_rule_metrics(
      rule_metrics_view.Config(
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
