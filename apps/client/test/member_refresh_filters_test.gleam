import gleam/option as opt

import domain/view_mode
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/client_state/member/pool as member_pool
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
      member_refresh_filters.PeopleRefresh,
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
      member_refresh_filters.PoolRefresh,
      opt.Some(2),
      opt.Some(7),
      " rollout ",
    )
}

pub fn capabilities_refresh_keeps_work_filters_test() {
  let assert task_operations_api.TaskFilters(
    status: opt.None,
    type_id: opt.Some(2),
    capability_id: opt.Some(7),
    q: opt.Some("rollout"),
    blocked: opt.None,
  ) =
    member_refresh_filters.task_filters(
      member_refresh_filters.CapabilitiesRefresh,
      opt.Some(2),
      opt.Some(7),
      "rollout",
    )
}

pub fn plan_kanban_refresh_keeps_work_filters_test() {
  let assert task_operations_api.TaskFilters(
    status: opt.None,
    type_id: opt.Some(2),
    capability_id: opt.Some(7),
    q: opt.Some("rollout"),
    blocked: opt.None,
  ) =
    member_refresh_filters.task_filters(
      member_refresh_filters.PlanKanbanRefresh,
      opt.Some(2),
      opt.Some(7),
      "rollout",
    )
}

pub fn plan_structure_refresh_ignores_invisible_work_filters_test() {
  let assert task_operations_api.TaskFilters(
    status: opt.None,
    type_id: opt.None,
    capability_id: opt.None,
    q: opt.None,
    blocked: opt.None,
  ) =
    member_refresh_filters.task_filters(
      member_refresh_filters.PlanStructureRefresh,
      opt.Some(2),
      opt.Some(7),
      "rollout",
    )
}

pub fn task_filter_usage_matches_refresh_surface_test() {
  let assert False =
    member_refresh_filters.uses_task_filters(
      member_refresh_filters.PeopleRefresh,
    )
  let assert True =
    member_refresh_filters.uses_task_filters(member_refresh_filters.PoolRefresh)
  let assert True =
    member_refresh_filters.uses_task_filters(
      member_refresh_filters.CapabilitiesRefresh,
    )
  let assert True =
    member_refresh_filters.uses_task_filters(
      member_refresh_filters.PlanKanbanRefresh,
    )
  let assert False =
    member_refresh_filters.uses_task_filters(
      member_refresh_filters.PlanStructureRefresh,
    )
}

pub fn active_task_filters_are_surface_aware_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_filters_type_id: opt.Some(2),
      member_filters_capability_id: opt.Some(7),
      member_filters_q: " rollout ",
    )

  let assert True =
    member_refresh_filters.has_active_task_filters(
      member_refresh_filters.PoolRefresh,
      pool,
    )
  let assert False =
    member_refresh_filters.has_active_task_filters(
      member_refresh_filters.PlanStructureRefresh,
      pool,
    )
}

pub fn task_filters_for_pool_uses_pool_work_filters_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_filters_type_id: opt.Some(2),
      member_filters_capability_id: opt.Some(7),
      member_filters_q: " rollout ",
    )

  let assert task_operations_api.TaskFilters(
    status: opt.None,
    type_id: opt.Some(2),
    capability_id: opt.Some(7),
    q: opt.Some("rollout"),
    blocked: opt.None,
  ) =
    member_refresh_filters.task_filters_for_pool(
      member_refresh_filters.PlanKanbanRefresh,
      pool,
    )
}

pub fn refresh_surface_distinguishes_plan_structure_from_kanban_test() {
  let assert member_refresh_filters.PlanStructureRefresh =
    member_refresh_filters.surface(view_mode.Cards, member_pool.PlanStructure)
  let assert member_refresh_filters.PlanKanbanRefresh =
    member_refresh_filters.surface(view_mode.Cards, member_pool.PlanKanban)
}
