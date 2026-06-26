import gleam/option as opt

import domain/view_mode
import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/view_mode_update
import scrumbringer_client/url_state

fn context(selected_project_id: opt.Option(Int)) -> view_mode_update.Context {
  view_mode_update.Context(selected_project_id: selected_project_id)
}

pub fn try_update_changes_view_mode_and_preserves_project_route_test() {
  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      member_pool.default_model(),
      pool_messages.ViewModeChanged(view_mode.People),
      context(opt.Some(7)),
    )

  let assert view_mode.People = next.view_mode
  let assert opt.None = next.member_card_depth_filter
  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert opt.Some(7) = url_state.project(state)
  let assert view_mode.People = url_state.view(state)
}

pub fn try_update_changes_view_mode_without_project_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_card_depth_filter: opt.Some(2),
    )
  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      model,
      pool_messages.ViewModeChanged(view_mode.Cards),
      context(opt.None),
    )

  let assert view_mode.Cards = next.view_mode
  let assert opt.None = next.member_card_depth_filter
  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert opt.None = url_state.project(state)
  let assert view_mode.Cards = url_state.view(state)
}

pub fn try_update_ignores_non_view_mode_messages_test() {
  let assert opt.None =
    view_mode_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      context(opt.Some(7)),
    )
}

pub fn plan_mode_change_to_kanban_cancels_move_mode_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_plan_move_mode: member_pool.PlanMovingCard(3, "New"),
      member_plan_move_error: opt.Some("error"),
      member_plan_move_in_flight: True,
    )

  let assert opt.Some(view_mode_update.Update(next, _)) =
    view_mode_update.try_update(
      model,
      pool_messages.MemberPlanModeChanged("kanban"),
      context(opt.Some(7)),
    )

  let assert member_pool.PlanKanban = next.member_plan_mode
  let assert member_pool.PlanNotMoving = next.member_plan_move_mode
  let assert opt.None = next.member_plan_move_error
  let assert False = next.member_plan_move_in_flight
}

pub fn view_mode_change_preserves_work_filters_in_route_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_capability_scope: capability_scope.MyCapabilities,
      member_filters_type_id: opt.Some(2),
      member_filters_capability_id: opt.Some(7),
      member_filters_q: " rollout ",
    )

  let assert opt.Some(view_mode_update.Update(_next, route_policy)) =
    view_mode_update.try_update(
      model,
      pool_messages.ViewModeChanged(view_mode.Capabilities),
      context(opt.Some(42)),
    )

  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert opt.Some(42) = url_state.project(state)
  let assert view_mode.Capabilities = url_state.view(state)
  let assert capability_scope.MyCapabilities = url_state.capability_scope(state)
  let assert opt.Some(2) = url_state.type_filter(state)
  let assert opt.Some(7) = url_state.capability_filter(state)
  let assert opt.Some("rollout") = url_state.search(state)
}

pub fn view_mode_change_to_people_omits_invisible_work_filters_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_capability_scope: capability_scope.MyCapabilities,
      member_filters_type_id: opt.Some(2),
      member_filters_capability_id: opt.Some(7),
      member_filters_q: "rollout",
    )

  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      model,
      pool_messages.ViewModeChanged(view_mode.People),
      context(opt.Some(42)),
    )

  let assert view_mode.People = next.view_mode
  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert view_mode.People = url_state.view(state)
  let assert capability_scope.AllCapabilities =
    url_state.capability_scope(state)
  let assert opt.None = url_state.type_filter(state)
  let assert opt.None = url_state.capability_filter(state)
  let assert opt.None = url_state.search(state)
}

pub fn view_mode_change_to_plan_structure_omits_scope_type_and_capability_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_capability_scope: capability_scope.MyCapabilities,
      member_filters_type_id: opt.Some(2),
      member_filters_capability_id: opt.Some(7),
      member_filters_q: "rollout",
    )

  let assert opt.Some(view_mode_update.Update(_next, route_policy)) =
    view_mode_update.try_update(
      model,
      pool_messages.ViewModeChanged(view_mode.Cards),
      context(opt.Some(42)),
    )

  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert view_mode.Cards = url_state.view(state)
  let assert url_state.PlanStructureParam = url_state.plan_mode(state)
  let assert capability_scope.AllCapabilities =
    url_state.capability_scope(state)
  let assert opt.None = url_state.type_filter(state)
  let assert opt.None = url_state.capability_filter(state)
  let assert opt.Some("rollout") = url_state.search(state)
}

pub fn plan_mode_change_to_kanban_preserves_work_filters_in_route_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_capability_scope: capability_scope.MyCapabilities,
      member_filters_type_id: opt.Some(2),
      member_filters_capability_id: opt.Some(7),
      member_filters_q: "rollout",
    )

  let assert opt.Some(view_mode_update.Update(_next, route_policy)) =
    view_mode_update.try_update(
      model,
      pool_messages.MemberPlanModeChanged("kanban"),
      context(opt.Some(42)),
    )

  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert view_mode.Cards = url_state.view(state)
  let assert url_state.PlanKanbanParam = url_state.plan_mode(state)
  let assert capability_scope.MyCapabilities = url_state.capability_scope(state)
  let assert opt.Some(2) = url_state.type_filter(state)
  let assert opt.Some(7) = url_state.capability_filter(state)
  let assert opt.Some("rollout") = url_state.search(state)
}

pub fn plan_mode_change_to_structure_clears_invisible_work_filters_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_plan_mode: member_pool.PlanKanban,
      member_capability_scope: capability_scope.MyCapabilities,
      member_filters_type_id: opt.Some(2),
      member_filters_capability_id: opt.Some(7),
      member_filters_q: "rollout",
    )

  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      model,
      pool_messages.MemberPlanModeChanged("structure"),
      context(opt.Some(42)),
    )

  let assert member_pool.PlanStructure = next.member_plan_mode
  let assert capability_scope.AllCapabilities = next.member_capability_scope
  let assert opt.None = next.member_filters_type_id
  let assert opt.None = next.member_filters_capability_id
  let assert "rollout" = next.member_filters_q
  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert view_mode.Cards = url_state.view(state)
  let assert url_state.PlanStructureParam = url_state.plan_mode(state)
  let assert capability_scope.AllCapabilities =
    url_state.capability_scope(state)
  let assert opt.None = url_state.type_filter(state)
  let assert opt.None = url_state.capability_filter(state)
  let assert opt.Some("rollout") = url_state.search(state)
}
