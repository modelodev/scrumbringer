import domain/card.{type Card, Active, Card, Closed, Draft}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/i18n/locale

fn base_card(id: Int, title: String, parent_id, state) -> Card {
  Card(
    ..domain_fixtures.card(id, 1, title),
    parent_card_id: parent_id,
    state: state,
  )
}

fn task(id: Int, title: String, type_id: Int, card_id) -> Task {
  Task(..domain_fixtures.task(id, title, type_id), card_id: card_id)
}

fn claimed_task(id: Int, title: String, type_id: Int, card_id) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: task_state.Taken,
    )
  Task(..task(id, title, type_id, card_id), state: state)
}

fn config(scope: scope_view.Scope) -> scope_view.Config(String) {
  scope_view.Config(
    locale: locale.En,
    cards: [
      base_card(1, "Platform Epic", None, Draft),
      base_card(2, "Checkout Story", Some(1), Active),
      base_card(3, "Closed Story", Some(1), Closed),
      base_card(4, "Nested Task Group", Some(2), Draft),
    ],
    tasks: [
      task(10, "Wire direct task", 1, Some(2)),
      claimed_task(11, "Backend claimed", 2, Some(2)),
    ],
    depth_names: [
      scope_view.DepthName(1, "Epic", "Epics"),
      scope_view.DepthName(2, "Story", "Stories"),
    ],
    scope: scope,
    include_closed: False,
    on_card_opened: fn(_) { "card" },
    on_task_opened: fn(_) { "task" },
    on_include_closed_toggled: "closed",
  )
}

pub fn depth_scope_hides_closed_cards_by_default_test() {
  let html =
    scope_view.view(config(scope_view.DepthScope(2)))
    |> element.to_document_string

  render_assertions.contains(html, "Stories")
  render_assertions.contains(html, "Checkout Story")
  render_assertions.contains(
    html,
    "Review nested cards and their tasks in this scope.",
  )
  render_assertions.not_contains(html, "Closed Story")
  render_assertions.not_contains(html, "Tracking")
  render_assertions.not_contains(html, "Execution")
}

pub fn card_scope_shows_direct_subcards_or_tasks_test() {
  let html =
    scope_view.view(config(scope_view.CardScope(2)))
    |> element.to_document_string

  render_assertions.contains(html, "Nested Task Group")
  render_assertions.contains(html, "Direct tasks")
  render_assertions.contains(html, "Wire direct task")
  render_assertions.not_contains(html, "Platform Epic")
}

pub fn include_closed_filter_reveals_closed_cards_test() {
  let html =
    scope_view.view(
      scope_view.Config(
        ..config(scope_view.DepthScope(2)),
        include_closed: True,
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Closed Story")
  render_assertions.contains(html, "Incluir cerradas")
}

pub fn depth_scope_empty_state_is_actionable_test() {
  let html =
    scope_view.view(config(scope_view.DepthScope(4)))
    |> element.to_document_string

  render_assertions.contains(html, "No cards at this level")
  render_assertions.contains(html, "Create a card at this level")
}

pub fn scope_copy_uses_spanish_locale_test() {
  let html =
    scope_view.view(
      scope_view.Config(..config(scope_view.CardScope(2)), locale: locale.Es),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Alcance de tarjeta")
  render_assertions.contains(html, "Tareas directas")
  render_assertions.contains(
    html,
    "Revisa tarjetas anidadas y sus tareas dentro de este alcance.",
  )
}

pub fn many_cards_in_depth_remain_scannable_test() {
  let cards = [
    base_card(1, "One", None, Draft),
    base_card(2, "Two", None, Draft),
    base_card(3, "Three", None, Draft),
    base_card(4, "Four", None, Draft),
    base_card(5, "Five", None, Draft),
    base_card(6, "Six", None, Draft),
  ]
  let html =
    scope_view.view(
      scope_view.Config(..config(scope_view.DepthScope(1)), cards: cards),
    )
    |> element.to_document_string

  render_assertions.contains(
    html,
    "hierarchy-scope-grid hierarchy-scope-grid-dense",
  )
  render_assertions.contains(html, "data-testid=\"hierarchy-scope-card\"")
}

pub fn mobile_sidebar_navigation_preserves_current_scope_test() {
  let html =
    scope_view.view(config(scope_view.CardScope(2)))
    |> element.to_document_string

  render_assertions.contains(html, "data-scope=\"card:2\"")
  render_assertions.contains(html, "hierarchy-scope-scope-shell")
}
