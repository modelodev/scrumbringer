//// Member view-mode routing transitions.

import gleam/option as opt

import domain/view_mode
import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/plan/url as plan_url
import scrumbringer_client/features/pool/member_route_policy
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/options as helpers_options
import scrumbringer_client/url_state

pub type Context {
  Context(selected_project_id: opt.Option(Int))
}

pub type RoutePolicy {
  NoRouteChange
  ReplaceMemberRoute(url_state.UrlState)
}

pub type Update {
  Update(member_pool.Model, RoutePolicy)
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: Context,
) -> opt.Option(Update) {
  case inner {
    pool_messages.ViewModeChanged(mode) ->
      opt.Some(view_mode_changed(model, mode, context))
    pool_messages.MemberPlanModeChanged(value) ->
      opt.Some(plan_mode_changed(model, value, context))
    _ -> opt.None
  }
}

fn view_mode_changed(
  model: member_pool.Model,
  mode: view_mode.ViewMode,
  context: Context,
) -> Update {
  let Context(selected_project_id: selected_project_id) = context
  let state =
    member_route_policy.state(
      selected_project_id,
      destination_for_view_mode(mode),
      filters(model),
    )

  Update(
    member_pool.Model(
      ..model,
      view_mode: mode,
      member_card_depth_filter: opt.None,
    ),
    ReplaceMemberRoute(state),
  )
}

fn plan_mode_changed(
  model: member_pool.Model,
  value: String,
  context: Context,
) -> Update {
  let mode = plan_url.mode_from_control_value(value)
  let Context(selected_project_id: selected_project_id) = context
  let state =
    member_route_policy.state(
      selected_project_id,
      destination_for_plan_mode(mode),
      filters(model),
    )

  let model = case mode {
    member_pool.PlanKanban -> model
    member_pool.PlanStructure ->
      member_pool.Model(
        ..model,
        member_capability_scope: capability_scope.default(),
        member_filters_type_id: opt.None,
        member_filters_capability_id: opt.None,
      )
  }

  Update(
    member_pool.Model(
      ..model,
      view_mode: view_mode.Cards,
      member_plan_mode: mode,
      member_plan_move_mode: member_pool.PlanNotMoving,
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
      member_plan_move_error: opt.None,
      member_plan_move_in_flight: False,
    ),
    ReplaceMemberRoute(state),
  )
}

fn destination_for_view_mode(
  mode: view_mode.ViewMode,
) -> member_route_policy.Destination {
  case mode {
    view_mode.Pool -> member_route_policy.PoolDestination
    view_mode.Capabilities -> member_route_policy.CapabilitiesDestination
    view_mode.People -> member_route_policy.PeopleDestination
    view_mode.Cards -> member_route_policy.PlanStructureDestination
  }
}

fn destination_for_plan_mode(
  mode: member_pool.PlanMode,
) -> member_route_policy.Destination {
  case mode {
    member_pool.PlanKanban -> member_route_policy.PlanKanbanDestination
    member_pool.PlanStructure -> member_route_policy.PlanStructureDestination
  }
}

fn filters(model: member_pool.Model) -> member_route_policy.WorkFilters {
  member_route_policy.WorkFilters(
    capability_scope: model.member_capability_scope,
    type_filter: model.member_filters_type_id,
    capability_filter: model.member_filters_capability_id,
    search: helpers_options.search_to_opt(model.member_filters_q),
  )
}
