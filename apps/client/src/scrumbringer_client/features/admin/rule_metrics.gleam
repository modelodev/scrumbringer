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
//// - **update.gleam**: Re-exports handlers from here
//// - **view.gleam**: Renders the rule metrics tab UI

import gleam/option.{None, Some}
import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, pool_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/update_helpers

// =============================================================================
// Date Range Handlers
// =============================================================================

/// Handle from date change.
pub fn handle_from_changed(model: Model, from: String) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(..admin, admin_rule_metrics_from: from)
    }),
    effect.none(),
  )
}

/// Handle to date change.
pub fn handle_to_changed(model: Model, to: String) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(..admin, admin_rule_metrics_to: to)
    }),
    effect.none(),
  )
}

/// Handle from date change with auto-refresh.
pub fn handle_from_changed_and_refresh(
  model: Model,
  from: String,
) -> #(Model, Effect(Msg)) {
  let to = model.admin.admin_rule_metrics_to
  // Only fetch if both dates are set
  case from == "" || to == "" {
    True -> #(
      update_admin(model, fn(admin) {
        admin_state.AdminModel(..admin, admin_rule_metrics_from: from)
      }),
      effect.none(),
    )
    False -> {
      let model =
        update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            admin_rule_metrics_from: from,
            admin_rule_metrics: Loading,
          )
        })
      #(
        model,
        api_workflows.get_org_rule_metrics(from, to, fn(result) {
          pool_msg(pool_messages.AdminRuleMetricsFetched(result))
        }),
      )
    }
  }
}

/// Handle to date change with auto-refresh.
pub fn handle_to_changed_and_refresh(
  model: Model,
  to: String,
) -> #(Model, Effect(Msg)) {
  let from = model.admin.admin_rule_metrics_from
  // Only fetch if both dates are set
  case from == "" || to == "" {
    True -> #(
      update_admin(model, fn(admin) {
        admin_state.AdminModel(..admin, admin_rule_metrics_to: to)
      }),
      effect.none(),
    )
    False -> {
      let model =
        update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            admin_rule_metrics_to: to,
            admin_rule_metrics: Loading,
          )
        })
      #(
        model,
        api_workflows.get_org_rule_metrics(from, to, fn(result) {
          pool_msg(pool_messages.AdminRuleMetricsFetched(result))
        }),
      )
    }
  }
}

/// Handle refresh clicked.
pub fn handle_refresh_clicked(model: Model) -> #(Model, Effect(Msg)) {
  let from = model.admin.admin_rule_metrics_from
  let to = model.admin.admin_rule_metrics_to

  // Only fetch if both dates are set
  case from == "" || to == "" {
    True -> #(model, effect.none())
    False -> {
      let model =
        update_admin(model, fn(admin) {
          admin_state.AdminModel(..admin, admin_rule_metrics: Loading)
        })
      // Use org-wide metrics (project filtering can be added later)
      #(
        model,
        api_workflows.get_org_rule_metrics(from, to, fn(result) {
          pool_msg(pool_messages.AdminRuleMetricsFetched(result))
        }),
      )
    }
  }
}

/// Handle quick range button click (sets dates and fetches immediately).
pub fn handle_quick_range_clicked(
  model: Model,
  from: String,
  to: String,
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        admin_rule_metrics_from: from,
        admin_rule_metrics_to: to,
        admin_rule_metrics: Loading,
      )
    })
  #(
    model,
    api_workflows.get_org_rule_metrics(from, to, fn(result) {
      pool_msg(pool_messages.AdminRuleMetricsFetched(result))
    }),
  )
}

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle rule metrics fetch success.
pub fn handle_fetched_ok(
  model: Model,
  metrics: List(api_workflows.OrgWorkflowMetricsSummary),
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(..admin, admin_rule_metrics: Loaded(metrics))
    }),
    effect.none(),
  )
}

/// Handle rule metrics fetch error.
pub fn handle_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        admin_state.AdminModel(..admin, admin_rule_metrics: Failed(err))
      }),
      effect.none(),
    )
  })
}

/// Initialize the rule metrics tab with default date range (last 30 days).
pub fn init_tab(model: Model) -> #(Model, Effect(Msg)) {
  // Set default dates if not already set: from 30 days ago to today
  case
    model.admin.admin_rule_metrics_from == ""
    || model.admin.admin_rule_metrics_to == ""
  {
    True -> {
      let to = client_ffi.date_today()
      let from = client_ffi.date_days_ago(30)
      #(
        update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            admin_rule_metrics_from: from,
            admin_rule_metrics_to: to,
          )
        }),
        effect.none(),
      )
    }
    False -> #(model, effect.none())
  }
}

// =============================================================================
// Drill-down Handlers
// =============================================================================

/// Handle workflow expansion toggle (to show per-rule metrics).
pub fn handle_workflow_expanded(
  model: Model,
  workflow_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.admin.admin_rule_metrics_expanded_workflow == Some(workflow_id) {
    // Collapse if already expanded
    True -> #(
      update_admin(model, fn(admin) {
        admin_state.AdminModel(
          ..admin,
          admin_rule_metrics_expanded_workflow: None,
          admin_rule_metrics_workflow_details: NotAsked,
        )
      }),
      effect.none(),
    )
    // Expand this workflow and fetch its details
    False -> {
      let model =
        update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            admin_rule_metrics_expanded_workflow: Some(workflow_id),
            admin_rule_metrics_workflow_details: Loading,
          )
        })
      #(
        model,
        api_workflows.get_workflow_metrics(workflow_id, fn(result) {
          pool_msg(pool_messages.AdminRuleMetricsWorkflowDetailsFetched(result))
        }),
      )
    }
  }
}

/// Handle workflow details fetch success.
pub fn handle_workflow_details_fetched_ok(
  model: Model,
  details: api_workflows.WorkflowMetrics,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        admin_rule_metrics_workflow_details: Loaded(details),
      )
    }),
    effect.none(),
  )
}

/// Handle workflow details fetch error.
pub fn handle_workflow_details_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        admin_state.AdminModel(
          ..admin,
          admin_rule_metrics_workflow_details: Failed(err),
        )
      }),
      effect.none(),
    )
  })
}

/// Handle drill-down click on a rule (to see executions).
pub fn handle_drilldown_clicked(
  model: Model,
  rule_id: Int,
) -> #(Model, Effect(Msg)) {
  let from = model.admin.admin_rule_metrics_from
  let to = model.admin.admin_rule_metrics_to

  // Fetch detailed metrics and executions for this rule
  let model =
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        admin_rule_metrics_drilldown_rule_id: Some(rule_id),
        admin_rule_metrics_rule_details: Loading,
        admin_rule_metrics_executions: Loading,
        admin_rule_metrics_exec_offset: 0,
      )
    })

  let details_effect =
    api_workflows.get_rule_metrics_detailed(rule_id, from, to, fn(result) {
      pool_msg(pool_messages.AdminRuleMetricsRuleDetailsFetched(result))
    })

  let executions_effect =
    api_workflows.get_rule_executions(rule_id, from, to, 20, 0, fn(result) {
      pool_msg(pool_messages.AdminRuleMetricsExecutionsFetched(result))
    })

  #(model, effect.batch([details_effect, executions_effect]))
}

/// Handle drill-down modal close.
pub fn handle_drilldown_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        admin_rule_metrics_drilldown_rule_id: None,
        admin_rule_metrics_rule_details: NotAsked,
        admin_rule_metrics_executions: NotAsked,
        admin_rule_metrics_exec_offset: 0,
      )
    }),
    effect.none(),
  )
}

/// Handle rule details fetch success.
pub fn handle_rule_details_fetched_ok(
  model: Model,
  details: api_workflows.RuleMetricsDetailed,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        admin_rule_metrics_rule_details: Loaded(details),
      )
    }),
    effect.none(),
  )
}

/// Handle rule details fetch error.
pub fn handle_rule_details_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        admin_state.AdminModel(
          ..admin,
          admin_rule_metrics_rule_details: Failed(err),
        )
      }),
      effect.none(),
    )
  })
}

/// Handle executions fetch success.
pub fn handle_executions_fetched_ok(
  model: Model,
  response: api_workflows.RuleExecutionsResponse,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        admin_rule_metrics_executions: Loaded(response),
      )
    }),
    effect.none(),
  )
}

/// Handle executions fetch error.
pub fn handle_executions_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        admin_state.AdminModel(
          ..admin,
          admin_rule_metrics_executions: Failed(err),
        )
      }),
      effect.none(),
    )
  })
}

/// Handle executions pagination.
pub fn handle_exec_page_changed(
  model: Model,
  offset: Int,
) -> #(Model, Effect(Msg)) {
  case model.admin.admin_rule_metrics_drilldown_rule_id {
    None -> #(model, effect.none())
    Some(rule_id) -> {
      let from = model.admin.admin_rule_metrics_from
      let to = model.admin.admin_rule_metrics_to
      let model =
        update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            admin_rule_metrics_executions: Loading,
            admin_rule_metrics_exec_offset: offset,
          )
        })
      #(
        model,
        api_workflows.get_rule_executions(
          rule_id,
          from,
          to,
          20,
          offset,
          fn(result) {
            pool_msg(pool_messages.AdminRuleMetricsExecutionsFetched(result))
          },
        ),
      )
    }
  }
}
