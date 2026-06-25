import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/metrics.{type MyMetrics, MyMetrics, WindowDays}
import domain/remote.{Loaded, NotAsked}
import scrumbringer_client/client_state
import scrumbringer_client/features/pool/metrics_route
import scrumbringer_client/features/pool/msg as pool_messages

fn member_metrics() -> MyMetrics {
  MyMetrics(
    window_days: WindowDays(30),
    claimed_count: 3,
    released_count: 1,
    closed_count: 2,
  )
}

pub fn try_update_routes_member_metrics_success_test() {
  let metrics = member_metrics()

  let assert opt.Some(#(next, fx)) =
    metrics_route.try_update(
      client_state.default_model(),
      pool_messages.MemberMetricsFetched(Ok(metrics)),
    )

  let assert Loaded(loaded_metrics) = next.member.metrics.member_metrics
  let assert True = loaded_metrics == metrics
  let assert True = fx == effect.none()
}

pub fn try_update_handles_admin_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert opt.Some(#(next, fx)) =
    metrics_route.try_update(
      client_state.default_model(),
      pool_messages.AdminMetricsUsersFetched(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert NotAsked = next.admin.metrics.admin_metrics_users
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_metrics_messages_test() {
  let assert opt.None =
    metrics_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
    )
}
