import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote.{NotAsked}
import scrumbringer_client/client_state
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/rule_metrics_route

pub fn try_update_routes_rule_metrics_date_changes_test() {
  let assert opt.Some(#(next, fx)) =
    rule_metrics_route.try_update(
      client_state.default_model(),
      pool_messages.AdminRuleMetricsFromChanged("2026-01-01"),
    )

  let assert "2026-01-01" = next.admin.metrics.admin_rule_metrics_from
  let assert True = fx == effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert opt.Some(#(next, fx)) =
    rule_metrics_route.try_update(
      client_state.default_model(),
      pool_messages.AdminRuleMetricsFetched(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert NotAsked = next.admin.metrics.admin_rule_metrics
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_rule_metrics_messages_test() {
  let assert opt.None =
    rule_metrics_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPoolFiltersToggled,
    )
}
