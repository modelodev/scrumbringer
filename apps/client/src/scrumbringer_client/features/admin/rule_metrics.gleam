//// Admin rule metrics tab update handlers.
////
//// ## Mission
////
//// Handles rule metrics tab operations in the admin panel.
////
//// ## Responsibilities
////
//// - Date range input changes
//// - Fetch org-wide rule metrics
//// - Handle fetch results
//// - Drill-down to per-rule details
//// - Fetch rule executions
////
//// ## Relations
////
//// - **update.gleam**: Assembles local transitions with root messages/auth
//// - **view.gleam**: Renders the rule metrics tab UI

import gleam/option.{type Option, None, Some}
import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/features/pool/msg as pool_messages

pub type Context(parent_msg) {
  Context(
    on_rule_metrics_fetched: fn(
      ApiResult(List(api_rule_metrics.OrgWorkflowMetricsSummary)),
    ) ->
      parent_msg,
    on_workflow_details_fetched: fn(ApiResult(api_rule_metrics.WorkflowMetrics)) ->
      parent_msg,
    on_rule_details_fetched: fn(ApiResult(api_rule_metrics.RuleMetricsDetailed)) ->
      parent_msg,
    on_executions_fetched: fn(
      ApiResult(api_rule_metrics.RuleExecutionsResponse),
    ) ->
      parent_msg,
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(admin_metrics.Model, Effect(parent_msg), AuthPolicy)
}

// =============================================================================
// Date Range Handlers
// =============================================================================

pub fn try_update(
  model: admin_metrics.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> Option(Update(parent_msg)) {
  case inner {
    pool_messages.AdminRuleMetricsFetched(Ok(metrics)) ->
      handle_fetched_ok(model, metrics)
      |> without_auth_check

    pool_messages.AdminRuleMetricsFetched(Error(err)) ->
      handle_fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.AdminRuleMetricsFromChanged(from) ->
      handle_from_changed(model, from)
      |> without_auth_check

    pool_messages.AdminRuleMetricsToChanged(to) ->
      handle_to_changed(model, to)
      |> without_auth_check

    pool_messages.AdminRuleMetricsFromChangedAndRefresh(from) ->
      handle_from_changed_and_refresh(model, from, context)
      |> without_auth_check

    pool_messages.AdminRuleMetricsToChangedAndRefresh(to) ->
      handle_to_changed_and_refresh(model, to, context)
      |> without_auth_check

    pool_messages.AdminRuleMetricsRefreshClicked ->
      handle_refresh_clicked(model, context)
      |> without_auth_check

    pool_messages.AdminRuleMetricsQuickRangeClicked(from, to) ->
      handle_quick_range_clicked(model, from, to, context)
      |> without_auth_check

    pool_messages.AdminRuleMetricsWorkflowExpanded(workflow_id) ->
      handle_workflow_expanded(model, workflow_id, context)
      |> without_auth_check

    pool_messages.AdminRuleMetricsWorkflowDetailsFetched(Ok(details)) ->
      handle_workflow_details_fetched_ok(model, details)
      |> without_auth_check

    pool_messages.AdminRuleMetricsWorkflowDetailsFetched(Error(err)) ->
      handle_workflow_details_fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.AdminRuleMetricsDrilldownClicked(rule_id) ->
      handle_drilldown_clicked(model, rule_id, context)
      |> without_auth_check

    pool_messages.AdminRuleMetricsDrilldownClosed ->
      handle_drilldown_closed(model)
      |> without_auth_check

    pool_messages.AdminRuleMetricsRuleDetailsFetched(Ok(details)) ->
      handle_rule_details_fetched_ok(model, details)
      |> without_auth_check

    pool_messages.AdminRuleMetricsRuleDetailsFetched(Error(err)) ->
      handle_rule_details_fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.AdminRuleMetricsExecutionsFetched(Ok(response)) ->
      handle_executions_fetched_ok(model, response)
      |> without_auth_check

    pool_messages.AdminRuleMetricsExecutionsFetched(Error(err)) ->
      handle_executions_fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.AdminRuleMetricsExecPageChanged(offset) ->
      handle_exec_page_changed(model, offset, context)
      |> without_auth_check

    _ -> None
  }
}

fn without_auth_check(
  result: #(admin_metrics.Model, Effect(parent_msg)),
) -> Option(Update(parent_msg)) {
  let #(model, fx) = result
  Some(Update(model, fx, NoAuthCheck))
}

fn with_auth_check(
  result: #(admin_metrics.Model, Effect(parent_msg)),
  err: ApiError,
) -> Option(Update(parent_msg)) {
  let #(model, fx) = result
  Some(Update(model, fx, CheckAuth(err)))
}

/// Handle from date change.
fn handle_from_changed(
  model: admin_metrics.Model,
  from: String,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(admin_metrics.Model(..model, admin_rule_metrics_from: from), effect.none())
}

/// Handle to date change.
fn handle_to_changed(
  model: admin_metrics.Model,
  to: String,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(admin_metrics.Model(..model, admin_rule_metrics_to: to), effect.none())
}

/// Handle from date change with auto-refresh.
fn handle_from_changed_and_refresh(
  model: admin_metrics.Model,
  from: String,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  let to = model.admin_rule_metrics_to
  // Only fetch if both dates are set
  case from == "" || to == "" {
    True -> #(
      admin_metrics.Model(..model, admin_rule_metrics_from: from),
      effect.none(),
    )
    False -> {
      let model =
        admin_metrics.Model(
          ..model,
          admin_rule_metrics_from: from,
          admin_rule_metrics: Loading,
        )
      #(
        model,
        api_rule_metrics.get_org_rule_metrics(
          date_range(from, to),
          context.on_rule_metrics_fetched,
        ),
      )
    }
  }
}

/// Handle to date change with auto-refresh.
fn handle_to_changed_and_refresh(
  model: admin_metrics.Model,
  to: String,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  let from = model.admin_rule_metrics_from
  // Only fetch if both dates are set
  case from == "" || to == "" {
    True -> #(
      admin_metrics.Model(..model, admin_rule_metrics_to: to),
      effect.none(),
    )
    False -> {
      let model =
        admin_metrics.Model(
          ..model,
          admin_rule_metrics_to: to,
          admin_rule_metrics: Loading,
        )
      #(
        model,
        api_rule_metrics.get_org_rule_metrics(
          date_range(from, to),
          context.on_rule_metrics_fetched,
        ),
      )
    }
  }
}

/// Handle refresh clicked.
fn handle_refresh_clicked(
  model: admin_metrics.Model,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  let from = model.admin_rule_metrics_from
  let to = model.admin_rule_metrics_to

  // Only fetch if both dates are set
  case from == "" || to == "" {
    True -> #(model, effect.none())
    False -> {
      let model = admin_metrics.Model(..model, admin_rule_metrics: Loading)
      // Use org-wide metrics (project filtering can be added later)
      #(
        model,
        api_rule_metrics.get_org_rule_metrics(
          date_range(from, to),
          context.on_rule_metrics_fetched,
        ),
      )
    }
  }
}

/// Handle quick range button click (sets dates and fetches immediately).
fn handle_quick_range_clicked(
  model: admin_metrics.Model,
  from: String,
  to: String,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  let model =
    admin_metrics.Model(
      ..model,
      admin_rule_metrics_from: from,
      admin_rule_metrics_to: to,
      admin_rule_metrics: Loading,
    )
  #(
    model,
    api_rule_metrics.get_org_rule_metrics(
      date_range(from, to),
      context.on_rule_metrics_fetched,
    ),
  )
}

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle rule metrics fetch success.
fn handle_fetched_ok(
  model: admin_metrics.Model,
  metrics: List(api_rule_metrics.OrgWorkflowMetricsSummary),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_rule_metrics: Loaded(metrics)),
    effect.none(),
  )
}

/// Handle rule metrics fetch error.
fn handle_fetched_error(
  model: admin_metrics.Model,
  err: ApiError,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_rule_metrics: Failed(err)),
    effect.none(),
  )
}

/// Initialize the rule metrics tab with default date range (last 30 days).
pub fn init_tab(
  model: admin_metrics.Model,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  // Set default dates if not already set: from 30 days ago to today
  case
    model.admin_rule_metrics_from == "" || model.admin_rule_metrics_to == ""
  {
    True -> {
      let to = client_ffi.date_today()
      let from = client_ffi.date_days_ago(30)
      let model =
        admin_metrics.Model(
          ..model,
          admin_rule_metrics_from: from,
          admin_rule_metrics_to: to,
          admin_rule_metrics: Loading,
        )
      #(
        model,
        api_rule_metrics.get_org_rule_metrics(
          date_range(from, to),
          context.on_rule_metrics_fetched,
        ),
      )
    }
    False ->
      case model.admin_rule_metrics {
        NotAsked -> {
          let model = admin_metrics.Model(..model, admin_rule_metrics: Loading)
          #(
            model,
            api_rule_metrics.get_org_rule_metrics(
              date_range(
                model.admin_rule_metrics_from,
                model.admin_rule_metrics_to,
              ),
              context.on_rule_metrics_fetched,
            ),
          )
        }
        _ -> #(model, effect.none())
      }
  }
}

// =============================================================================
// Drill-down Handlers
// =============================================================================

/// Handle workflow expansion toggle (to show per-rule metrics).
fn handle_workflow_expanded(
  model: admin_metrics.Model,
  workflow_id: Int,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  case model.admin_rule_metrics_expanded_workflow == Some(workflow_id) {
    // Collapse if already expanded
    True -> #(
      admin_metrics.Model(
        ..model,
        admin_rule_metrics_expanded_workflow: None,
        admin_rule_metrics_workflow_details: NotAsked,
      ),
      effect.none(),
    )
    // Expand this workflow and fetch its details
    False -> {
      let model =
        admin_metrics.Model(
          ..model,
          admin_rule_metrics_expanded_workflow: Some(workflow_id),
          admin_rule_metrics_workflow_details: Loading,
        )
      #(
        model,
        api_rule_metrics.get_workflow_metrics(
          workflow_id,
          context.on_workflow_details_fetched,
        ),
      )
    }
  }
}

/// Handle workflow details fetch success.
fn handle_workflow_details_fetched_ok(
  model: admin_metrics.Model,
  details: api_rule_metrics.WorkflowMetrics,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(
      ..model,
      admin_rule_metrics_workflow_details: Loaded(details),
    ),
    effect.none(),
  )
}

/// Handle workflow details fetch error.
fn handle_workflow_details_fetched_error(
  model: admin_metrics.Model,
  err: ApiError,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(
      ..model,
      admin_rule_metrics_workflow_details: Failed(err),
    ),
    effect.none(),
  )
}

/// Handle drill-down click on a rule (to see executions).
fn handle_drilldown_clicked(
  model: admin_metrics.Model,
  rule_id: Int,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  let from = model.admin_rule_metrics_from
  let to = model.admin_rule_metrics_to

  // Fetch detailed metrics and executions for this rule
  let model =
    admin_metrics.Model(
      ..model,
      admin_rule_metrics_drilldown_rule_id: Some(rule_id),
      admin_rule_metrics_rule_details: Loading,
      admin_rule_metrics_executions: Loading,
      admin_rule_metrics_exec_offset: 0,
    )

  let details_effect =
    api_rule_metrics.get_rule_metrics_detailed(
      rule_id,
      date_range(from, to),
      context.on_rule_details_fetched,
    )

  let executions_effect =
    api_rule_metrics.get_rule_executions(
      rule_id,
      date_range(from, to),
      20,
      0,
      context.on_executions_fetched,
    )

  #(model, effect.batch([details_effect, executions_effect]))
}

/// Handle drill-down modal close.
fn handle_drilldown_closed(
  model: admin_metrics.Model,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(
      ..model,
      admin_rule_metrics_drilldown_rule_id: None,
      admin_rule_metrics_rule_details: NotAsked,
      admin_rule_metrics_executions: NotAsked,
      admin_rule_metrics_exec_offset: 0,
    ),
    effect.none(),
  )
}

/// Handle rule details fetch success.
fn handle_rule_details_fetched_ok(
  model: admin_metrics.Model,
  details: api_rule_metrics.RuleMetricsDetailed,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(
      ..model,
      admin_rule_metrics_rule_details: Loaded(details),
    ),
    effect.none(),
  )
}

/// Handle rule details fetch error.
fn handle_rule_details_fetched_error(
  model: admin_metrics.Model,
  err: ApiError,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_rule_metrics_rule_details: Failed(err)),
    effect.none(),
  )
}

/// Handle executions fetch success.
fn handle_executions_fetched_ok(
  model: admin_metrics.Model,
  response: api_rule_metrics.RuleExecutionsResponse,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(
      ..model,
      admin_rule_metrics_executions: Loaded(response),
    ),
    effect.none(),
  )
}

/// Handle executions fetch error.
fn handle_executions_fetched_error(
  model: admin_metrics.Model,
  err: ApiError,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_rule_metrics_executions: Failed(err)),
    effect.none(),
  )
}

/// Handle executions pagination.
fn handle_exec_page_changed(
  model: admin_metrics.Model,
  offset: Int,
  context: Context(parent_msg),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  case model.admin_rule_metrics_drilldown_rule_id {
    None -> #(model, effect.none())
    Some(rule_id) -> {
      let from = model.admin_rule_metrics_from
      let to = model.admin_rule_metrics_to
      let model =
        admin_metrics.Model(
          ..model,
          admin_rule_metrics_executions: Loading,
          admin_rule_metrics_exec_offset: offset,
        )
      #(
        model,
        api_rule_metrics.get_rule_executions(
          rule_id,
          date_range(from, to),
          20,
          offset,
          context.on_executions_fetched,
        ),
      )
    }
  }
}

fn date_range(from: String, to: String) -> api_rule_metrics.CalendarDateRange {
  api_rule_metrics.calendar_date_range(from, to)
}
