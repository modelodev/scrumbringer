import domain/card.{type Card, Active, Card}
import gleam/option.{None, Some}
import lustre/element
import support/render_assertions

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/scope_bar
import scrumbringer_client/i18n/locale

fn card(id: Int, title: String) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: None,
    title: title,
    description: "",
    color: None,
    state: Active,
    task_count: 0,
    closed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}

pub fn scope_bar_card_mode_uses_search_without_duplicate_select_test() {
  let html =
    scope_bar.Config(
      locale: locale.En,
      cards: [card(2, "Checkout"), card(1, "Sprint")],
      depth_names: [scope_view.DepthName(1, "Epic", "Epics")],
      scope_kind: member_pool.PlanScopeCard,
      selected_depth: None,
      selected_card_id: Some(2),
      card_query: "",
      show_closed: True,
      id_prefix: "test-plan",
      mode_controls: [],
      refinement_controls: [],
      show_closed_control: True,
      on_scope_kind_change: fn(_) { 0 },
      on_scope_depth_change: fn(_) { 0 },
      on_scope_card_change: fn(_) { 0 },
      on_scope_card_search_change: fn(_) { 0 },
      on_closed_toggled: fn(_) { 0 },
    )
    |> scope_bar.view
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"plan-scope-bar\"")
  render_assertions.contains(html, "data-testid=\"plan-scope-card-search\"")
  render_assertions.contains(html, "aria-expanded=\"false\"")
  render_assertions.contains(html, "Checkout")
  render_assertions.contains(html, "Epic #2")
  render_assertions.not_contains(html, "Checkout - Checkout")
  render_assertions.not_contains(html, "data-testid=\"plan-scope-card-option\"")
  render_assertions.not_contains(html, "data-testid=\"plan-scope-card\"")
  render_assertions.not_contains(html, "Lens")
}

pub fn scope_bar_can_render_optional_mode_controls_test() {
  let html =
    scope_bar.Config(
      locale: locale.En,
      cards: [],
      depth_names: [scope_view.DepthName(1, "Feature", "Features")],
      scope_kind: member_pool.PlanScopeLevel,
      selected_depth: Some(1),
      selected_card_id: None,
      card_query: "",
      show_closed: False,
      id_prefix: "test-plan",
      mode_controls: [
        scope_bar.ModeControl(
          label: "List",
          value: "list",
          active: True,
          testid: "capability-mode-list",
          on_select: 1,
        ),
      ],
      refinement_controls: [],
      show_closed_control: True,
      on_scope_kind_change: fn(_) { 0 },
      on_scope_depth_change: fn(_) { 0 },
      on_scope_card_change: fn(_) { 0 },
      on_scope_card_search_change: fn(_) { 0 },
      on_closed_toggled: fn(_) { 0 },
    )
    |> scope_bar.view
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"capability-mode-list\"")
  render_assertions.contains(html, "aria-pressed=\"true\"")
  render_assertions.contains(html, "data-testid=\"plan-scope-depth\"")
}

pub fn scope_bar_marks_refinement_controls_as_work_filter_bar_test() {
  let html =
    scope_bar.Config(
      locale: locale.En,
      cards: [],
      depth_names: [scope_view.DepthName(1, "Feature", "Features")],
      scope_kind: member_pool.PlanScopeLevel,
      selected_depth: Some(1),
      selected_card_id: None,
      card_query: "",
      show_closed: False,
      id_prefix: "test-plan",
      mode_controls: [],
      refinement_controls: [element.text("Filter")],
      show_closed_control: True,
      on_scope_kind_change: fn(_) { 0 },
      on_scope_depth_change: fn(_) { 0 },
      on_scope_card_change: fn(_) { 0 },
      on_scope_card_search_change: fn(_) { 0 },
      on_closed_toggled: fn(_) { 0 },
    )
    |> scope_bar.view
    |> element.to_document_string

  render_assertions.contains(
    html,
    "class=\"plan-refinement-controls work-filter-bar\"",
  )
  render_assertions.contains(html, "data-testid=\"work-filter-bar\"")
}

pub fn scope_bar_filters_card_options_by_query_test() {
  let html =
    scope_bar.Config(
      locale: locale.En,
      cards: [card(2, "Checkout"), card(1, "Sprint")],
      depth_names: [scope_view.DepthName(1, "Epic", "Epics")],
      scope_kind: member_pool.PlanScopeCard,
      selected_depth: None,
      selected_card_id: None,
      card_query: "sprint",
      show_closed: True,
      id_prefix: "test-plan",
      mode_controls: [],
      refinement_controls: [],
      show_closed_control: True,
      on_scope_kind_change: fn(_) { 0 },
      on_scope_depth_change: fn(_) { 0 },
      on_scope_card_change: fn(_) { 0 },
      on_scope_card_search_change: fn(_) { 0 },
      on_closed_toggled: fn(_) { 0 },
    )
    |> scope_bar.view
    |> element.to_document_string

  render_assertions.contains(html, "value=\"sprint\"")
  render_assertions.contains(html, "aria-expanded=\"true\"")
  render_assertions.contains(html, "data-testid=\"plan-scope-card-option\"")
  render_assertions.contains(html, "Sprint")
  render_assertions.not_contains(html, "Checkout")
}
