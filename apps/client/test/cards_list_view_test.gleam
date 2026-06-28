import gleam/option as opt
import lustre/element
import support/render_assertions

import domain/card.{Card, Draft}
import scrumbringer_client/features/cards/list_view
import scrumbringer_client/i18n/locale

fn sample_card() {
  Card(
    id: 3,
    project_id: 7,
    parent_card_id: opt.None,
    title: "Customer Portal",
    description: "Visible to members",
    color: opt.None,
    state: Draft,
    task_count: 4,
    closed_count: 1,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    has_new_notes: False,
  )
}

fn config(cards, pending_count) -> list_view.Config(String) {
  list_view.Config(
    locale: locale.En,
    cards: cards,
    pending_count: pending_count,
    on_card_opened: fn(_) { "open" },
  )
}

pub fn cards_list_view_renders_cards_without_root_model_test() {
  let html =
    list_view.view(config([sample_card()], 0))
    |> element.to_document_string

  render_assertions.contains(html, "fichas-list")
  render_assertions.contains(html, "Customer Portal")
  render_assertions.contains(html, "Visible to members")
  render_assertions.contains(html, "role=\"button\"")
  render_assertions.contains(html, "1 of 4 tasks closed")
}

pub fn cards_list_view_renders_empty_state_without_root_model_test() {
  let html =
    list_view.view(config([], 0))
    |> element.to_document_string

  render_assertions.contains(html, "No cards")
  render_assertions.contains(html, "Cards group related tasks")
}

pub fn cards_list_view_renders_loading_when_pending_without_root_model_test() {
  let html =
    list_view.view(config([], 2))
    |> element.to_document_string

  render_assertions.contains(html, "Loading")
  render_assertions.not_contains(html, "No cards")
}
