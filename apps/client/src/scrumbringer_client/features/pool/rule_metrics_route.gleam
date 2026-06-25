//// Root-aware adapter for admin rule metrics reachable from pool dispatch.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/features/admin/rule_metrics as rule_metrics_workflow
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/route_support

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    rule_metrics_workflow.try_update(
      model.admin.metrics,
      inner,
      model.core.selected_project_id,
      context(),
    )
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: rule_metrics_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let rule_metrics_workflow.Update(metrics, fx, auth_policy) = update

  route_support.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    #(set_admin_metrics(model, metrics), fx)
  })
}

fn context() -> rule_metrics_workflow.Context(client_state.Msg) {
  rule_metrics_workflow.Context(
    on_rule_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsFetched(result))
    },
    on_workflow_details_fetched: fn(result) {
      client_state.pool_msg(
        pool_messages.AdminRuleMetricsWorkflowDetailsFetched(result),
      )
    },
    on_rule_details_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsRuleDetailsFetched(
        result,
      ))
    },
    on_executions_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsExecutionsFetched(
        result,
      ))
    },
    on_project_executions_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminProjectRuleExecutionsFetched(
        result,
      ))
    },
  )
}

fn auth_error(policy: rule_metrics_workflow.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    rule_metrics_workflow.NoAuthCheck -> opt.None
    rule_metrics_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn set_admin_metrics(
  model: client_state.Model,
  metrics: admin_metrics.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, metrics: metrics)
  })
}
