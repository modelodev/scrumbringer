import domain/card.{type Card, Active, Card}
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/scope_bar
import scrumbringer_client/i18n/locale

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

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
    completed_count: 0,
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
      show_closed: True,
      id_prefix: "test-plan",
      mode_controls: [],
      on_scope_kind_change: fn(_) { 0 },
      on_scope_depth_change: fn(_) { 0 },
      on_scope_card_change: fn(_) { 0 },
      on_closed_toggled: fn(_) { 0 },
    )
    |> scope_bar.view
    |> element.to_document_string

  assert_contains(html, "data-testid=\"plan-scope-bar\"")
  assert_contains(html, "data-testid=\"plan-scope-card-search\"")
  assert_contains(html, "Checkout #2")
  assert_not_contains(html, "data-testid=\"plan-scope-card\"")
  assert_not_contains(html, "Lens")
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
      on_scope_kind_change: fn(_) { 0 },
      on_scope_depth_change: fn(_) { 0 },
      on_scope_card_change: fn(_) { 0 },
      on_closed_toggled: fn(_) { 0 },
    )
    |> scope_bar.view
    |> element.to_document_string

  assert_contains(html, "data-testid=\"capability-mode-list\"")
  assert_contains(html, "aria-pressed=\"true\"")
  assert_contains(html, "data-testid=\"plan-scope-depth\"")
}
