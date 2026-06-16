import gleam/option
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/features/admin/rule_metrics
import scrumbringer_client/features/pool/msg as pool_messages

fn context() -> rule_metrics.Context(String) {
  rule_metrics.Context(
    on_rule_metrics_fetched: fn(_) { "rule-metrics-fetched" },
    on_workflow_details_fetched: fn(_) { "workflow-details-fetched" },
    on_rule_details_fetched: fn(_) { "rule-details-fetched" },
    on_executions_fetched: fn(_) { "executions-fetched" },
  )
}

fn update(
  model: admin_metrics.Model,
  inner: pool_messages.Msg,
) -> rule_metrics.Update(String) {
  let assert option.Some(update) =
    rule_metrics.try_update(model, inner, context())
  update
}

fn workflow_summary(id: Int) -> api_rule_metrics.OrgWorkflowMetricsSummary {
  api_rule_metrics.OrgWorkflowMetricsSummary(
    workflow_id: id,
    workflow_name: "Workflow",
    project_id: 2,
    rule_count: 3,
    evaluated_count: 5,
    applied_count: 4,
    suppressed_count: 1,
  )
}

fn workflow_details(id: Int) -> api_rule_metrics.WorkflowMetrics {
  api_rule_metrics.WorkflowMetrics(
    workflow_id: id,
    workflow_name: "Workflow",
    rules: [],
  )
}

fn rule_details(id: Int) -> api_rule_metrics.RuleMetricsDetailed {
  api_rule_metrics.RuleMetricsDetailed(
    rule_id: id,
    rule_name: "Rule",
    evaluated_count: 5,
    applied_count: 4,
    suppressed_count: 1,
    suppression_breakdown: api_rule_metrics.SuppressionBreakdown(
      idempotent: 1,
      not_user_triggered: 0,
      not_matching: 0,
      inactive: 0,
    ),
  )
}

fn executions_response(rule_id: Int) -> api_rule_metrics.RuleExecutionsResponse {
  api_rule_metrics.RuleExecutionsResponse(
    rule_id: rule_id,
    executions: [],
    pagination: api_rule_metrics.Pagination(limit: 20, offset: 0, total: 0),
  )
}

pub fn from_changed_updates_local_date_without_effect_test() {
  let rule_metrics.Update(next, fx, _) =
    update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsFromChanged("2026-01-01"),
    )

  let assert "2026-01-01" = next.admin_rule_metrics_from
  let assert True = fx == effect.none()
}

pub fn try_update_from_changed_returns_local_update_without_auth_test() {
  let assert option.Some(rule_metrics.Update(next, fx, auth_policy)) =
    rule_metrics.try_update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsFromChanged("2026-01-01"),
      context(),
    )

  let assert "2026-01-01" = next.admin_rule_metrics_from
  let assert rule_metrics.NoAuthCheck = auth_policy
  let assert True = fx == effect.none()
}

pub fn try_update_error_returns_local_update_with_auth_policy_test() {
  let err = ApiError(status: 500, code: "RULE_METRICS", message: "Boom")

  let assert option.Some(rule_metrics.Update(next, fx, auth_policy)) =
    rule_metrics.try_update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsFetched(Error(err)),
      context(),
    )
  let assert rule_metrics.CheckAuth(auth_err) = auth_policy

  let assert Failed(_) = next.admin_rule_metrics
  let assert True = auth_err == err
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_rule_metrics_messages_test() {
  let assert option.None =
    rule_metrics.try_update(
      admin_metrics.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      context(),
    )
}

pub fn from_changed_and_refresh_waits_for_complete_range_test() {
  let model =
    admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics_to: "",
    )

  let rule_metrics.Update(next, fx, _) =
    update(
      model,
      pool_messages.AdminRuleMetricsFromChangedAndRefresh("2026-01-01"),
    )

  let assert "2026-01-01" = next.admin_rule_metrics_from
  let assert NotAsked = next.admin_rule_metrics
  let assert True = fx == effect.none()
}

pub fn from_changed_and_refresh_fetches_when_range_is_complete_test() {
  let model =
    admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics_to: "2026-01-31",
    )

  let rule_metrics.Update(next, fx, _) =
    update(
      model,
      pool_messages.AdminRuleMetricsFromChangedAndRefresh("2026-01-01"),
    )

  let assert "2026-01-01" = next.admin_rule_metrics_from
  let assert Loading = next.admin_rule_metrics
  let assert False = fx == effect.none()
}

pub fn quick_range_sets_dates_and_fetches_test() {
  let rule_metrics.Update(next, fx, _) =
    update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsQuickRangeClicked(
        "2026-01-01",
        "2026-01-31",
      ),
    )

  let assert "2026-01-01" = next.admin_rule_metrics_from
  let assert "2026-01-31" = next.admin_rule_metrics_to
  let assert Loading = next.admin_rule_metrics
  let assert False = fx == effect.none()
}

pub fn fetched_ok_sets_loaded_metrics_test() {
  let metrics = [workflow_summary(7)]

  let rule_metrics.Update(next, fx, _) =
    update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsFetched(Ok(metrics)),
    )

  let assert Loaded([summary]) = next.admin_rule_metrics
  let assert 7 = summary.workflow_id
  let assert True = fx == effect.none()
}

pub fn fetched_error_sets_failed_metrics_test() {
  let err = ApiError(status: 500, code: "RULE_METRICS", message: "Boom")

  let rule_metrics.Update(next, fx, _) =
    update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsFetched(Error(err)),
    )

  let assert Failed(_) = next.admin_rule_metrics
  let assert True = fx == effect.none()
}

pub fn workflow_expanded_collapses_current_workflow_test() {
  let model =
    admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics_expanded_workflow: option.Some(7),
      admin_rule_metrics_workflow_details: Loaded(workflow_details(7)),
    )

  let rule_metrics.Update(next, fx, _) =
    update(model, pool_messages.AdminRuleMetricsWorkflowExpanded(7))

  let assert option.None = next.admin_rule_metrics_expanded_workflow
  let assert NotAsked = next.admin_rule_metrics_workflow_details
  let assert True = fx == effect.none()
}

pub fn workflow_expanded_fetches_new_workflow_details_test() {
  let rule_metrics.Update(next, fx, _) =
    update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsWorkflowExpanded(7),
    )

  let assert option.Some(7) = next.admin_rule_metrics_expanded_workflow
  let assert Loading = next.admin_rule_metrics_workflow_details
  let assert False = fx == effect.none()
}

pub fn drilldown_clicked_fetches_rule_details_and_executions_test() {
  let model =
    admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics_from: "2026-01-01",
      admin_rule_metrics_to: "2026-01-31",
      admin_rule_metrics_exec_offset: 40,
    )

  let rule_metrics.Update(next, fx, _) =
    update(model, pool_messages.AdminRuleMetricsDrilldownClicked(9))

  let assert option.Some(9) = next.admin_rule_metrics_drilldown_rule_id
  let assert Loading = next.admin_rule_metrics_rule_details
  let assert Loading = next.admin_rule_metrics_executions
  let assert 0 = next.admin_rule_metrics_exec_offset
  let assert False = fx == effect.none()
}

pub fn drilldown_closed_resets_drilldown_state_test() {
  let model =
    admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics_drilldown_rule_id: option.Some(9),
      admin_rule_metrics_rule_details: Loaded(rule_details(9)),
      admin_rule_metrics_executions: Loaded(executions_response(9)),
      admin_rule_metrics_exec_offset: 20,
    )

  let rule_metrics.Update(next, fx, _) =
    update(model, pool_messages.AdminRuleMetricsDrilldownClosed)

  let assert option.None = next.admin_rule_metrics_drilldown_rule_id
  let assert NotAsked = next.admin_rule_metrics_rule_details
  let assert NotAsked = next.admin_rule_metrics_executions
  let assert 0 = next.admin_rule_metrics_exec_offset
  let assert True = fx == effect.none()
}

pub fn exec_page_changed_ignores_missing_drilldown_rule_test() {
  let rule_metrics.Update(next, fx, _) =
    update(
      admin_metrics.default_model(),
      pool_messages.AdminRuleMetricsExecPageChanged(20),
    )

  let assert option.None = next.admin_rule_metrics_drilldown_rule_id
  let assert 0 = next.admin_rule_metrics_exec_offset
  let assert True = fx == effect.none()
}

pub fn exec_page_changed_fetches_current_drilldown_rule_test() {
  let model =
    admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_rule_metrics_drilldown_rule_id: option.Some(9),
      admin_rule_metrics_from: "2026-01-01",
      admin_rule_metrics_to: "2026-01-31",
    )

  let rule_metrics.Update(next, fx, _) =
    update(model, pool_messages.AdminRuleMetricsExecPageChanged(20))

  let assert Loading = next.admin_rule_metrics_executions
  let assert 20 = next.admin_rule_metrics_exec_offset
  let assert False = fx == effect.none()
}
