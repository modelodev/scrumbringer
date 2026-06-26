//// Pure member route policy.

import gleam/option.{type Option, None, Some}

import domain/view_mode
import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/url_state

pub type Destination {
  PoolDestination
  CapabilitiesDestination
  PeopleDestination
  PlanStructureDestination
  PlanKanbanDestination
}

pub type WorkFilters {
  WorkFilters(
    capability_scope: CapabilityScope,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search: Option(String),
  )
}

pub fn state(
  selected_project_id: Option(Int),
  destination: Destination,
  filters: WorkFilters,
) -> url_state.UrlState {
  base_state(selected_project_id)
  |> with_destination(destination)
  |> with_visible_filters(destination, filters)
}

fn base_state(selected_project_id: Option(Int)) -> url_state.UrlState {
  case selected_project_id {
    Some(project_id) -> url_state.with_project(url_state.empty(), project_id)
    None -> url_state.empty()
  }
}

fn with_destination(
  state: url_state.UrlState,
  destination: Destination,
) -> url_state.UrlState {
  case destination {
    PoolDestination -> url_state.with_view(state, view_mode.Pool)
    CapabilitiesDestination ->
      url_state.with_view(state, view_mode.Capabilities)
    PeopleDestination -> url_state.with_view(state, view_mode.People)
    PlanStructureDestination ->
      state
      |> url_state.with_view(view_mode.Cards)
      |> url_state.with_plan_mode(url_state.PlanStructureParam)
    PlanKanbanDestination ->
      state
      |> url_state.with_view(view_mode.Cards)
      |> url_state.with_plan_mode(url_state.PlanKanbanParam)
  }
}

fn with_visible_filters(
  state: url_state.UrlState,
  destination: Destination,
  filters: WorkFilters,
) -> url_state.UrlState {
  let WorkFilters(
    capability_scope: capability_scope,
    type_filter: type_filter,
    capability_filter: capability_filter,
    search: search,
  ) = filters

  case destination {
    PoolDestination | CapabilitiesDestination | PlanKanbanDestination ->
      state
      |> url_state.with_capability_scope(capability_scope)
      |> url_state.with_type_filter(type_filter)
      |> url_state.with_capability_filter(capability_filter)
      |> url_state.with_search(search)
    PlanStructureDestination ->
      state
      |> url_state.with_search(search)
    PeopleDestination -> state
  }
}
