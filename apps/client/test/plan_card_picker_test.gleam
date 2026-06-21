import domain/card.{type Card, type CardPhase, Active, Card, Closed, Draft}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/card_picker

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn duplicate_titles_resolve_only_with_path_or_id_test() {
  let options = card_picker.active_options(cards(), depth_names())
  let assert Ok(first) = list.find(options, fn(option) { option.id == 2 })
  let assert Ok(second) = list.find(options, fn(option) { option.id == 4 })

  assert_contains(first.label, "Checkout")
  assert_contains(first.label, "Root / Web / Checkout")
  assert_contains(first.label, "Story #2")
  assert_contains(second.label, "Root / API / Checkout")
  assert_contains(second.label, "Story #4")
  let assert "" =
    card_picker.search_value_to_card_id(cards(), depth_names(), "Checkout")
  let assert "2" =
    card_picker.search_value_to_card_id(cards(), depth_names(), first.label)
  let assert "4" =
    card_picker.search_value_to_card_id(cards(), depth_names(), "#4")
}

pub fn picker_options_include_only_active_cards_test() {
  let labels =
    card_picker.active_options(cards(), depth_names())
    |> list.map(fn(option) { option.label })
    |> string.join(" | ")

  assert_contains(labels, "Root")
  assert_contains(labels, "Checkout")
  assert_not_contains(labels, "Draft Idea")
  assert_not_contains(labels, "Closed Release")
}

fn depth_names() -> List(scope_view.DepthName) {
  [
    scope_view.DepthName(1, "Initiative", "Initiatives"),
    scope_view.DepthName(2, "Feature", "Features"),
    scope_view.DepthName(3, "Story", "Stories"),
  ]
}

fn cards() -> List(Card) {
  [
    card(1, None, "Root", Active),
    card(3, Some(1), "Web", Active),
    card(2, Some(3), "Checkout", Active),
    card(5, Some(1), "API", Active),
    card(4, Some(5), "Checkout", Active),
    card(6, Some(1), "Draft Idea", Draft),
    card(7, Some(1), "Closed Release", Closed),
  ]
}

fn card(
  id: Int,
  parent_card_id: Option(Int),
  title: String,
  state: CardPhase,
) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: parent_card_id,
    title: title,
    description: "",
    color: None,
    state: state,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}
