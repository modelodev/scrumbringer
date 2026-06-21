//// Member pool filter update workflow.

import gleam/dict
import gleam/option as opt
import gleam/string

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/options as helpers_options

import domain/task_status

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(#(member_pool.Model, Bool)) {
  case inner {
    pool_messages.MemberPoolStatusChanged(value) ->
      opt.Some(handle_status_changed(model, value))
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
    pool_messages.MemberPlanModeChanged(value) ->
      opt.Some(handle_plan_mode_changed(model, value))
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
        member_pool.Model(..model, member_plan_show_closed: opt.Some(value)),
        False,
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

pub fn handle_status_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  let next_status = case string.trim(value) {
    "" -> opt.None
    _ ->
      case task_status.parse_task_status(value) {
        Ok(status) -> opt.Some(status)
        Error(_) -> opt.None
      }
  }

  #(member_pool.Model(..model, member_filters_status: next_status), True)
}

pub fn handle_type_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(
    member_pool.Model(
      ..model,
      member_filters_type_id: helpers_options.empty_to_int_opt(value),
    ),
    True,
  )
}

pub fn handle_capability_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(
    member_pool.Model(
      ..model,
      member_filters_capability_id: helpers_options.empty_to_int_opt(value),
    ),
    True,
  )
}

pub fn handle_search_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(member_pool.Model(..model, member_filters_q: value), False)
}

pub fn handle_search_debounced(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(member_pool.Model(..model, member_filters_q: value), True)
}

pub fn handle_clear(model: member_pool.Model) -> #(member_pool.Model, Bool) {
  #(
    member_pool.Model(
      ..model,
      member_filters_status: opt.None,
      member_filters_type_id: opt.None,
      member_filters_capability_id: opt.None,
      member_filters_q: "",
      member_capability_scope: capability_scope.default(),
    ),
    True,
  )
}

pub fn handle_capability_scope_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  case capability_scope.parse(value) {
    Ok(next_scope) -> #(
      member_pool.Model(..model, member_capability_scope: next_scope),
      True,
    )

    Error(_) -> #(model, False)
  }
}

fn handle_plan_scope_kind_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  let kind = case string.trim(value) {
    "project" -> member_pool.PlanScopeProject
    "card" -> member_pool.PlanScopeCard
    _ -> member_pool.PlanScopeLevel
  }

  #(
    member_pool.Model(
      ..model,
      member_plan_scope_kind: kind,
      member_plan_scope_card_query: "",
      member_plan_show_closed: opt.None,
      member_plan_collapsed_cards: dict.new(),
    ),
    False,
  )
}

fn handle_plan_mode_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  let mode = case string.trim(value) {
    "kanban" -> member_pool.PlanKanban
    _ -> member_pool.PlanStructure
  }

  #(member_pool.Model(..model, member_plan_mode: mode), False)
}

fn handle_plan_capability_mode_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  let mode = case string.trim(value) {
    "matrix" -> member_pool.PlanCapabilityMatrix
    _ -> member_pool.PlanCapabilityList
  }

  #(member_pool.Model(..model, member_plan_capability_mode: mode), False)
}

fn handle_plan_scope_depth_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(
    member_pool.Model(
      ..model,
      member_card_depth_filter: helpers_options.empty_to_int_opt(value),
      member_plan_scope_kind: member_pool.PlanScopeLevel,
      member_plan_scope_card_query: "",
      member_plan_show_closed: opt.None,
      member_plan_collapsed_cards: dict.new(),
    ),
    False,
  )
}

fn handle_plan_scope_card_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(
    member_pool.Model(
      ..model,
      member_plan_scope_card_id: helpers_options.empty_to_int_opt(value),
      member_plan_scope_kind: member_pool.PlanScopeCard,
      member_plan_scope_card_query: "",
      member_plan_show_closed: opt.None,
      member_plan_collapsed_cards: dict.new(),
    ),
    False,
  )
}

fn handle_plan_scope_card_search_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(
    member_pool.Model(
      ..model,
      member_plan_scope_card_query: value,
      member_plan_scope_kind: member_pool.PlanScopeCard,
    ),
    False,
  )
}

fn handle_plan_status_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(
    member_pool.Model(
      ..model,
      member_plan_status_filter: parse_plan_status(value),
    ),
    False,
  )
}

fn handle_plan_sort_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Bool) {
  #(member_pool.Model(..model, member_plan_sort: parse_plan_sort(value)), False)
}

fn handle_plan_card_toggled(
  model: member_pool.Model,
  card_id: Int,
) -> #(member_pool.Model, Bool) {
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
    False,
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
