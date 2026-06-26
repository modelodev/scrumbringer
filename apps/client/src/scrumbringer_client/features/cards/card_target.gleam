//// Shared card target option helpers.

import domain/card.{type Card, Active}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import scrumbringer_client/features/cards/policy as card_policy
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/utils/card_queries

pub type CardTargetOption {
  CardTargetOption(
    id: Int,
    title: String,
    path: String,
    level_name: String,
    label: String,
    disabled_reason: Option(String),
  )
}

pub fn active_task_targets(
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> List(CardTargetOption) {
  cards
  |> list.filter(fn(card) {
    card.state == Active && !card_has_child_cards(cards, card)
  })
  |> sorted_options(cards, depth_names)
}

pub fn plan_scope_targets(
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> List(CardTargetOption) {
  cards
  |> list.filter(fn(card) { card.state == Active })
  |> sorted_options(cards, depth_names)
}

pub fn move_destination_targets(
  destinations: List(card_policy.MoveDestination),
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> List(CardTargetOption) {
  destinations
  |> list.map(fn(destination) {
    case destination {
      card_policy.ValidDestination(card) ->
        option_for_card(card, cards, depth_names)
      card_policy.InvalidDestination(card, reason) ->
        CardTargetOption(
          ..option_for_card(card, cards, depth_names),
          disabled_reason: Some(card_policy.move_blocked_reason_label(reason)),
        )
    }
  })
}

pub fn filter_options(
  options: List(CardTargetOption),
  query: String,
) -> List(CardTargetOption) {
  let normalized_query = normalize(query)

  case normalized_query {
    "" -> options
    _ ->
      options
      |> list.filter(fn(option) {
        string.contains(normalize(option.title), normalized_query)
        || string.contains(normalize(option.path), normalized_query)
        || string.contains(normalize(option.label), normalized_query)
        || normalize("#" <> int.to_string(option.id)) == normalized_query
        || normalize(int.to_string(option.id)) == normalized_query
      })
  }
}

pub fn selected_label(
  options: List(CardTargetOption),
  selected_card_id: Option(Int),
) -> String {
  case selected_card_id {
    Some(card_id) ->
      case list.find(options, fn(option) { option.id == card_id }) {
        Ok(option) -> option.label
        Error(_) -> ""
      }
    None -> ""
  }
}

pub fn search_value_to_card_id(
  options: List(CardTargetOption),
  value: String,
) -> String {
  let query = normalize(value)
  let matches =
    options
    |> list.filter(fn(option) {
      normalize(option.label) == query
      || normalize("#" <> int.to_string(option.id)) == query
      || normalize(int.to_string(option.id)) == query
    })

  case matches {
    [match] -> int.to_string(match.id)
    _ -> ""
  }
}

fn sorted_options(
  target_cards: List(Card),
  all_cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> List(CardTargetOption) {
  target_cards
  |> list.sort(fn(a, b) {
    string.compare(
      card_queries.card_path(a, all_cards),
      card_queries.card_path(b, all_cards),
    )
  })
  |> list.map(fn(card) { option_for_card(card, all_cards, depth_names) })
}

fn card_has_child_cards(cards: List(Card), card: Card) -> Bool {
  list.any(cards, fn(candidate) { candidate.parent_card_id == Some(card.id) })
}

fn option_for_card(
  card: Card,
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> CardTargetOption {
  let full_path = card_queries.card_path(card, cards)
  let parent_path = card_queries.parent_path(card, cards)
  let level_name =
    card_queries.depth_singular_label(
      depth_names,
      card_queries.card_depth(card, cards),
    )
  let visible_path = case parent_path {
    "" -> full_path
    _ -> parent_path <> " / " <> card.title
  }
  let label = case parent_path {
    "" -> card.title <> " - " <> level_name <> " #" <> int.to_string(card.id)
    _ ->
      card.title
      <> " - "
      <> visible_path
      <> " - "
      <> level_name
      <> " #"
      <> int.to_string(card.id)
  }

  CardTargetOption(
    id: card.id,
    title: card.title,
    path: visible_path,
    level_name: level_name,
    label: label,
    disabled_reason: None,
  )
}

fn normalize(value: String) -> String {
  value
  |> string.trim
  |> string.lowercase
}
