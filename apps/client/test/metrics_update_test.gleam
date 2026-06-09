import gleam/option
import lustre/effect

import domain/api_error.{ApiError}
import domain/metrics.{
  MyMetrics, OrgMetricsProjectTasksPayload, OrgMetricsUserOverview, WindowDays,
}
import domain/remote
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/features/metrics/update as metrics_update
import scrumbringer_client/features/pool/msg as pool_messages

pub fn member_metrics_success_loads_local_state_test() {
  let metrics =
    MyMetrics(
      window_days: WindowDays(30),
      claimed_count: 3,
      released_count: 1,
      completed_count: 2,
    )

  let #(next, fx) =
    metrics_update.handle_member_metrics_fetched_ok(
      member_metrics.default_model(),
      metrics,
    )

  let assert True = next.member_metrics == remote.Loaded(metrics)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_member_metrics_success_without_auth_test() {
  let metrics =
    MyMetrics(
      window_days: WindowDays(30),
      claimed_count: 3,
      released_count: 1,
      completed_count: 2,
    )

  let assert option.Some(metrics_update.MemberUpdate(
    next,
    fx,
    metrics_update.NoAuthCheck,
  )) =
    metrics_update.try_update(
      member_metrics.default_model(),
      admin_metrics.default_model(),
      pool_messages.MemberMetricsFetched(Ok(metrics)),
    )

  let assert True = next.member_metrics == remote.Loaded(metrics)
  let assert True = fx == effect.none()
}

pub fn member_metrics_error_sets_failed_local_state_test() {
  let err = ApiError(status: 500, code: "METRICS", message: "Server error")

  let #(next, fx) =
    metrics_update.handle_member_metrics_fetched_error(
      member_metrics.default_model(),
      err,
    )

  let assert True = next.member_metrics == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn admin_project_tasks_success_tracks_selected_project_test() {
  let payload =
    OrgMetricsProjectTasksPayload(
      window_days: WindowDays(14),
      project_id: 42,
      tasks: [],
    )

  let #(next, fx) =
    metrics_update.handle_admin_project_tasks_fetched_ok(
      admin_metrics.default_model(),
      payload,
    )

  let assert True = next.admin_metrics_project_tasks == remote.Loaded(payload)
  let assert True = next.admin_metrics_project_id == option.Some(42)
  let assert True = fx == effect.none()
}

pub fn admin_users_error_sets_failed_local_state_test() {
  let user =
    OrgMetricsUserOverview(
      user_id: 7,
      email: "user@example.test",
      claimed_count: 3,
      released_count: 1,
      completed_count: 2,
      ongoing_count: 0,
      last_claim_at: option.None,
    )
  let initial =
    admin_metrics.Model(
      ..admin_metrics.default_model(),
      admin_metrics_users: remote.Loaded([user]),
    )
  let err = ApiError(status: 500, code: "METRICS_USERS", message: "Boom")

  let #(next, fx) =
    metrics_update.handle_admin_users_fetched_error(initial, err)

  let assert True = next.admin_metrics_users == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_admin_users_error_with_auth_policy_test() {
  let err = ApiError(status: 500, code: "METRICS_USERS", message: "Boom")

  let assert option.Some(metrics_update.AdminUpdate(
    next,
    fx,
    metrics_update.CheckAuth(auth_err),
  )) =
    metrics_update.try_update(
      member_metrics.default_model(),
      admin_metrics.default_model(),
      pool_messages.AdminMetricsUsersFetched(Error(err)),
    )

  let assert True = auth_err == err
  let assert True = next.admin_metrics_users == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_metrics_messages_test() {
  let assert option.None =
    metrics_update.try_update(
      member_metrics.default_model(),
      admin_metrics.default_model(),
      pool_messages.MemberPoolSearchChanged("qa"),
    )
}
