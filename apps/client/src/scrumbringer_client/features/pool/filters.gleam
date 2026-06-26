//// Member pool filter update flow.

import gleam/dict
import gleam/option as opt
import gleam/string

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/member_refresh_filters
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/visibility
import scrumbringer_client/helpers/options as helpers_options

pub type RefreshPolicy {
  LocalOnly
  RefreshMemberData
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(#(member_pool.Model, RefreshPolicy)) {
  case inner {
    pool_messages.MemberPoolVisibilityChanged(value) ->
      opt.Some(handle_visibility_changed(model, value))
    pool_messages.MemberPoolTypeChanged(value) ->
      opt.Some(handle_type_changed(model, value))
    pool_messages.MemberPoolCapabilityChanged(value) ->
      opt.Some(handle_capability_changed(model, value))
    pool_messages.MemberPoolCapabilityScopeChanged(value) ->
      opt.Some(handle_capability_scope_changed(model, value))
    pool_messages.MemberClearFilters -> opt.Some(handle_clear(model))
    pool_messages.MemberPoolSearchChanged(value) ->
      opt.Some(handle_search_changed(model, value))
    pool_messages.MemberPoolSearchDebounced(value) ->
      opt.Some(handle_search_debounced(model, value))
    pool_messages.MemberPlanScopeKindChanged(value) ->
      opt.Some(handle_plan_scope_kind_changed(model, value))
    pool_messages.MemberPlanCapabilityModeChanged(value) ->
      opt.Some(handle_plan_capability_mode_changed(model, value))
    pool_messages.MemberPlanScopeDepthChanged(value) ->
      opt.Some(handle_plan_scope_depth_changed(model, value))
    pool_messages.MemberPlanScopeCardChanged(value) ->
      opt.Some(handle_plan_scope_card_changed(model, value))
    pool_messages.MemberPlanScopeCardSearchChanged(value) ->
      opt.Some(handle_plan_scope_card_search_changed(model, value))
    pool_messages.MemberPlanClosedToggled(value) ->
      opt.Some(#(
        member_pool.Model(
          ..model,
          member_plan_show_closed: opt.Some(value),
          member_plan_move_mode: member_pool.PlanNotMoving,
          member_plan_move_drag: member_pool.PlanMoveNotDragging,
          member_plan_move_error: opt.None,
          member_plan_move_in_flight: False,
        ),
        LocalOnly,
      ))
    pool_messages.MemberPlanStatusChanged(value) ->
      opt.Some(handle_plan_status_changed(model, value))
    pool_messages.MemberPlanSortChanged(value) ->
      opt.Some(handle_plan_sort_changed(model, value))
    pool_messages.MemberPlanCardToggled(card_id) ->
      opt.Some(handle_plan_card_toggled(model, card_id))
    _ -> opt.None
  }
}

pub fn handle_visibility_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  let next_visibility = case visibility.parse(value) {
    Ok(parsed) -> parsed
    Error(_) -> visibility.default()
  }

  #(
    member_pool.Model(..model, member_pool_visibility: next_visibility),
    LocalOnly,
  )
}

pub fn handle_type_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  let next =
    member_pool.Model(
      ..model,
      member_filters_type_id: helpers_options.empty_to_int_opt(value),
    )

  #(next, task_filter_change_policy(next))
}

pub fn handle_capability_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  let next =
    member_pool.Model(
      ..model,
      member_filters_capability_id: helpers_options.empty_to_int_opt(value),
    )

  #(next, task_filter_change_policy(next))
}

pub fn handle_search_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  #(member_pool.Model(..model, member_filters_q: value), LocalOnly)
}

pub fn handle_search_debounced(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  let next = member_pool.Model(..model, member_filters_q: value)

  #(next, task_filter_change_policy(next))
}

pub fn handle_clear(
  model: member_pool.Model,
) -> #(member_pool.Model, RefreshPolicy) {
  let refresh_policy = case
    member_refresh_filters.has_active_task_filters(
      refresh_surface(model),
      model,
    )
  {
    True -> RefreshMemberData
    False -> LocalOnly
  }

  #(
    member_pool.Model(
      ..model,
      member_pool_visibility: visibility.default(),
      member_filters_type_id: opt.None,
      member_filters_capability_id: opt.None,
      member_filters_q: "",
      member_capability_scope: capability_scope.default(),
    ),
    refresh_policy,
  )
}

fn task_filter_change_policy(model: member_pool.Model) -> RefreshPolicy {
  case member_refresh_filters.uses_task_filters(refresh_surface(model)) {
    True -> RefreshMemberData
    False -> LocalOnly
  }
}

fn refresh_surface(
  model: member_pool.Model,
) -> member_refresh_filters.TaskRefreshSurface {
  member_refresh_filters.surface(model.view_mode, model.member_plan_mode)
}

pub fn handle_capability_scope_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  case capability_scope.parse(value) {
    Ok(next_scope) -> #(
      member_pool.Model(..model, member_capability_scope: next_scope),
      LocalOnly,
    )

    Error(_) -> #(model, LocalOnly)
  }
}

fn handle_plan_scope_kind_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  let kind = case string.trim(value) {
    "project" -> member_pool.PlanScopeProject
    "card" -> member_pool.PlanScopeCard
    _ -> member_pool.PlanScopeLevel
  }

  #(
    member_pool.Model(
      ..model,
      member_plan_scope_kind: kind,
      member_plan_move_mode: member_pool.PlanNotMoving,
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
      member_plan_move_error: opt.None,
      member_plan_move_in_flight: False,
      member_plan_scope_card_query: "",
      member_plan_show_closed: opt.None,
      member_plan_collapsed_cards: dict.new(),
    ),
    LocalOnly,
  )
}

fn handle_plan_capability_mode_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  let mode = case string.trim(value) {
    "matrix" -> member_pool.PlanCapabilityMatrix
    _ -> member_pool.PlanCapabilityList
  }

  #(member_pool.Model(..model, member_plan_capability_mode: mode), LocalOnly)
}

fn handle_plan_scope_depth_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  #(
    member_pool.Model(
      ..model,
      member_card_depth_filter: helpers_options.empty_to_int_opt(value),
      member_plan_scope_kind: member_pool.PlanScopeLevel,
      member_plan_move_mode: member_pool.PlanNotMoving,
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
      member_plan_move_error: opt.None,
      member_plan_move_in_flight: False,
      member_plan_scope_card_query: "",
      member_plan_show_closed: opt.None,
      member_plan_collapsed_cards: dict.new(),
    ),
    LocalOnly,
  )
}

fn handle_plan_scope_card_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  #(
    member_pool.Model(
      ..model,
      member_plan_scope_card_id: helpers_options.empty_to_int_opt(value),
      member_plan_scope_kind: member_pool.PlanScopeCard,
      member_plan_move_mode: member_pool.PlanNotMoving,
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
      member_plan_move_error: opt.None,
      member_plan_move_in_flight: False,
      member_plan_scope_card_query: "",
      member_plan_show_closed: opt.None,
      member_plan_collapsed_cards: dict.new(),
    ),
    LocalOnly,
  )
}

fn handle_plan_scope_card_search_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  #(
    member_pool.Model(
      ..model,
      member_plan_scope_card_query: value,
      member_plan_scope_kind: member_pool.PlanScopeCard,
    ),
    LocalOnly,
  )
}

fn handle_plan_status_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  #(
    member_pool.Model(
      ..model,
      member_plan_status_filter: parse_plan_status(value),
      member_plan_move_mode: member_pool.PlanNotMoving,
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
      member_plan_move_error: opt.None,
      member_plan_move_in_flight: False,
    ),
    LocalOnly,
  )
}

fn handle_plan_sort_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, RefreshPolicy) {
  #(
    member_pool.Model(
      ..model,
      member_plan_sort: parse_plan_sort(value),
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
    ),
    LocalOnly,
  )
}

fn handle_plan_card_toggled(
  model: member_pool.Model,
  card_id: Int,
) -> #(member_pool.Model, RefreshPolicy) {
  let collapsed = case dict.get(model.member_plan_collapsed_cards, card_id) {
    Ok(True) -> False
    _ -> True
  }

  #(
    member_pool.Model(
      ..model,
      member_plan_collapsed_cards: dict.insert(
        model.member_plan_collapsed_cards,
        card_id,
        collapsed,
      ),
    ),
    LocalOnly,
  )
}

fn parse_plan_status(value: String) -> member_pool.PlanStatusFilter {
  case string.trim(value) {
    "draft" -> member_pool.PlanStatusDraft
    "active" -> member_pool.PlanStatusActive
    "closed" -> member_pool.PlanStatusClosed
    _ -> member_pool.PlanStatusAll
  }
}

fn parse_plan_sort(value: String) -> member_pool.PlanSort {
  case string.trim(value) {
    "state" -> member_pool.PlanSortState
    "due_date" -> member_pool.PlanSortDueDate
    "pool_impact" -> member_pool.PlanSortPoolImpact
    _ -> member_pool.PlanSortPath
  }
}
