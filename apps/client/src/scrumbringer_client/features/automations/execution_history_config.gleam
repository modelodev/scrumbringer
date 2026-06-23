//// Root-state adapter for automation execution history.

import gleam/option as opt
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/features/automations/execution_history
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type Callbacks(msg) {
  Callbacks(
    on_quick_range_clicked: fn(String, String) -> msg,
    on_from_changed: fn(String) -> msg,
    on_to_changed: fn(String) -> msg,
    on_workflow_expanded: fn(Int) -> msg,
    on_drilldown_clicked: fn(Int) -> msg,
    on_drilldown_closed: msg,
    on_exec_page_changed: fn(Int) -> msg,
  )
}

pub fn from_state(
  locale: Locale,
  metrics: admin_metrics.Model,
  selected_execution_id: opt.Option(Int),
  callbacks: Callbacks(msg),
) -> execution_history.Config(msg) {
  let today = client_ffi.date_today()
  let default_from = client_ffi.date_days_ago(30)
  let metrics = case
    metrics.admin_rule_metrics_from == "" || metrics.admin_rule_metrics_to == ""
  {
    True ->
      admin_metrics.Model(
        ..metrics,
        admin_rule_metrics_from: default_from,
        admin_rule_metrics_to: today,
      )
    False -> metrics
  }
  let quick_range = fn(label, days) {
    let from = client_ffi.date_days_ago(days)
    execution_history.QuickRange(
      label: i18n.t(locale, label),
      from: from,
      to: today,
      on_clicked: callbacks.on_quick_range_clicked(from, today),
    )
  }

  execution_history.Config(
    locale: locale,
    model: metrics,
    selected_execution_id: selected_execution_id,
    quick_ranges: [
      quick_range(i18n_text.RuleMetrics7Days, 7),
      quick_range(i18n_text.RuleMetrics30Days, 30),
      quick_range(i18n_text.RuleMetrics90Days, 90),
    ],
    on_from_changed: callbacks.on_from_changed,
    on_to_changed: callbacks.on_to_changed,
    on_workflow_expanded: callbacks.on_workflow_expanded,
    on_drilldown_clicked: callbacks.on_drilldown_clicked,
    on_drilldown_closed: callbacks.on_drilldown_closed,
    on_exec_page_changed: callbacks.on_exec_page_changed,
  )
}
