//// Scoped navigation URLs from Card Show into primary work surfaces.

import domain/card.{type Card}
import domain/view_mode
import scrumbringer_client/url_state

pub fn plan_url(card: Card) -> String {
  url(card, view_mode.Cards, url_state.PlanStructureParam)
}

pub fn kanban_url(card: Card) -> String {
  url(card, view_mode.Cards, url_state.PlanKanbanParam)
}

pub fn capabilities_url(card: Card) -> String {
  url(card, view_mode.Capabilities, url_state.PlanStructureParam)
}

pub fn people_url(card: Card) -> String {
  url(card, view_mode.People, url_state.PlanStructureParam)
}

fn url(
  card: Card,
  view: view_mode.ViewMode,
  plan_mode: url_state.PlanModeParam,
) -> String {
  url_state.empty()
  |> url_state.with_project(card.project_id)
  |> url_state.with_view(view)
  |> maybe_with_plan_mode(view, plan_mode)
  |> url_state.with_card_work_scope(card.id)
  |> url_state.to_app_url
}

fn maybe_with_plan_mode(
  state: url_state.UrlState,
  view: view_mode.ViewMode,
  plan_mode: url_state.PlanModeParam,
) -> url_state.UrlState {
  case view, plan_mode {
    view_mode.Cards, url_state.PlanKanbanParam ->
      url_state.with_plan_mode(state, plan_mode)
    _, _ -> state
  }
}
