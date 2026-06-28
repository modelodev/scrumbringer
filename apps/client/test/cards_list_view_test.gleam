import support/domain_fixtures
import support/render_assertions

import domain/card.{Card, Draft}
import scrumbringer_client/features/cards/list_view
import scrumbringer_client/i18n/locale

fn sample_card() {
  Card(
    ..domain_fixtures.card(3, 7, "Customer Portal"),
    description: "Visible to members",
    state: Draft,
    task_count: 4,
    closed_count: 1,
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
    |> render_assertions.html

  render_assertions.contains(html, "fichas-list")
  render_assertions.contains(html, "Customer Portal")
  render_assertions.contains(html, "Visible to members")
  render_assertions.contains(html, "role=\"button\"")
  render_assertions.contains(html, "1 of 4 tasks closed")
}

pub fn cards_list_view_renders_empty_state_without_root_model_test() {
  let html =
    list_view.view(config([], 0))
    |> render_assertions.html

  render_assertions.contains(html, "No cards")
  render_assertions.contains(html, "Cards group related tasks")
}

pub fn cards_list_view_renders_loading_when_pending_without_root_model_test() {
  let html =
    list_view.view(config([], 2))
    |> render_assertions.html

  render_assertions.contains(html, "Loading")
  render_assertions.not_contains(html, "No cards")
}
