import gleam/option as opt

import domain/view_mode
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/features/pool/member_refresh_filters

pub fn people_refresh_ignores_pool_filters_test() {
  let assert task_operations_api.TaskFilters(
    status: opt.None,
    type_id: opt.None,
    capability_id: opt.None,
    q: opt.None,
    blocked: opt.None,
  ) =
    member_refresh_filters.task_filters(
      view_mode.People,
      opt.Some(2),
      opt.Some(7),
      "rollout",
    )
}

pub fn pool_refresh_keeps_pool_filters_test() {
  let assert task_operations_api.TaskFilters(
    status: opt.None,
    type_id: opt.Some(2),
    capability_id: opt.Some(7),
    q: opt.Some("rollout"),
    blocked: opt.None,
  ) =
    member_refresh_filters.task_filters(
      view_mode.Pool,
      opt.Some(2),
      opt.Some(7),
      "rollout",
    )
}
