//// Root-aware adapter for member and admin metrics in pool dispatch.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/features/metrics/update as metrics_workflow
import scrumbringer_client/features/route_support

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    metrics_workflow.try_update(
      model.member.metrics,
      model.admin.metrics,
      inner,
    )
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: metrics_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case update {
    metrics_workflow.MemberUpdate(metrics, fx, auth_policy) ->
      route_support.apply_auth_check(
        model,
        route_support.auth_check_before(auth_error(auth_policy)),
        fn() { #(set_member_metrics(model, metrics), fx) },
      )
    metrics_workflow.AdminUpdate(metrics, fx, auth_policy) ->
      route_support.apply_auth_check(
        model,
        route_support.auth_check_before(auth_error(auth_policy)),
        fn() { #(set_admin_metrics(model, metrics), fx) },
      )
  }
}

fn auth_error(policy: metrics_workflow.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    metrics_workflow.NoAuthCheck -> opt.None
    metrics_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn set_member_metrics(
  model: client_state.Model,
  metrics: member_metrics.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(..member, metrics: metrics)
  })
}

fn set_admin_metrics(
  model: client_state.Model,
  metrics: admin_metrics.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, metrics: metrics)
  })
}
