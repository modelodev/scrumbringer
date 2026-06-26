import domain/card.{type Card, type CardPhase, Active, Card, Closed, Draft}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import scrumbringer_client/features/cards/card_target
import scrumbringer_client/features/cards/policy as card_policy
import scrumbringer_client/features/hierarchy/scope_view

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn duplicate_titles_resolve_only_with_path_or_id_test() {
  let options = card_target.plan_scope_targets(cards(), depth_names())
  let assert Ok(first) = list.find(options, fn(option) { option.id == 2 })
  let assert Ok(second) = list.find(options, fn(option) { option.id == 4 })

  assert_contains(first.label, "Checkout")
  assert_contains(first.label, "Root / Web / Checkout")
  assert_contains(first.label, "Story #2")
  assert_contains(second.label, "Root / API / Checkout")
  assert_contains(second.label, "Story #4")
  let assert "" = card_target.search_value_to_card_id(options, "Checkout")
  let assert "2" = card_target.search_value_to_card_id(options, first.label)
  let assert "4" = card_target.search_value_to_card_id(options, "#4")
}

pub fn plan_scope_targets_include_only_active_cards_test() {
  let labels =
    card_target.plan_scope_targets(cards(), depth_names())
    |> list.map(fn(option) { option.label })
    |> string.join(" | ")

  assert_contains(labels, "Root")
  assert_contains(labels, "Checkout")
  assert_not_contains(labels, "Draft Idea")
  assert_not_contains(labels, "Closed Release")
}

pub fn active_task_targets_include_only_active_leaf_cards_test() {
  let ids =
    card_target.active_task_targets(cards(), depth_names())
    |> list.map(fn(option) { option.id })

  let assert [4, 2] = ids
}

pub fn card_target_filters_options_by_title_path_and_id_test() {
  let options = card_target.plan_scope_targets(cards(), depth_names())

  let by_title =
    options
    |> card_target.filter_options("checkout")
    |> list.map(fn(option) { option.id })
  let by_path =
    options
    |> card_target.filter_options("api")
    |> list.map(fn(option) { option.id })
  let by_id =
    options
    |> card_target.filter_options("#4")
    |> list.map(fn(option) { option.id })

  let assert [4, 2] = by_title
  let assert [5, 4] = by_path
  let assert [4] = by_id
}

pub fn move_destination_targets_preserve_disabled_reasons_test() {
  let root = card(1, None, "Root", Active)
  let child = card(2, Some(1), "Child", Active)
  let options =
    card_target.move_destination_targets(
      [card_policy.InvalidDestination(child, card_policy.SelfOrDescendant)],
      [root, child],
      depth_names(),
    )

  let assert [option] = options
  let assert Some(reason) = option.disabled_reason
  assert_contains(reason, "propia")
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
    closed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}
