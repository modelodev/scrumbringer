import gleam/option as opt
import gleam/string
import lustre/element

import domain/card.{Card, Pendiente}
import scrumbringer_client/features/fichas/list_view
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn sample_card() {
  Card(
    id: 3,
    project_id: 7,
    milestone_id: opt.None,
    title: "Customer Portal",
    description: "Visible to members",
    color: opt.None,
    state: Pendiente,
    task_count: 4,
    completed_count: 1,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
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

pub fn fichas_list_view_renders_cards_without_root_model_test() {
  let html =
    list_view.view(config([sample_card()], 0))
    |> element.to_document_string

  assert_contains(html, "fichas-list")
  assert_contains(html, "Customer Portal")
  assert_contains(html, "Visible to members")
  assert_contains(html, "role=\"button\"")
  assert_contains(html, "1/4")
}

pub fn fichas_list_view_renders_empty_state_without_root_model_test() {
  let html =
    list_view.view(config([], 0))
    |> element.to_document_string

  assert_contains(html, "No cards")
  assert_contains(html, "Cards group related tasks")
}

pub fn fichas_list_view_renders_loading_when_pending_without_root_model_test() {
  let html =
    list_view.view(config([], 2))
    |> element.to_document_string

  assert_contains(html, "Loading")
  assert_not_contains(html, "No cards")
}
