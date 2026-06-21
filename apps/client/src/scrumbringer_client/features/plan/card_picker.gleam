//// Local card picker helpers for Plan scope selection.

import domain/card.{type Card, Active}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import scrumbringer_client/features/cards/detail_policy
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/utils/card_queries

pub type CardOption {
  CardOption(
    id: Int,
    title: String,
    path: String,
    level_name: String,
    label: String,
    disabled_reason: Option(String),
  )
}

pub fn active_options(
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> List(CardOption) {
  cards
  |> list.filter(fn(card) { card.state == Active })
  |> list.sort(fn(a, b) {
    string.compare(
      card_queries.card_path(a, cards),
      card_queries.card_path(b, cards),
    )
  })
  |> list.map(fn(card) { option_for_card(card, cards, depth_names) })
}

pub fn filter_options(
  options: List(CardOption),
  query: String,
) -> List(CardOption) {
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

pub fn move_destination_options(
  destinations: List(detail_policy.MoveDestination),
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> List(CardOption) {
  destinations
  |> list.map(fn(destination) {
    case destination {
      detail_policy.ValidDestination(card) ->
        option_for_card(card, cards, depth_names)
      detail_policy.InvalidDestination(card, reason) ->
        CardOption(
          ..option_for_card(card, cards, depth_names),
          disabled_reason: Some(detail_policy.move_blocked_reason_label(reason)),
        )
    }
  })
}

pub fn selected_label(
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
  selected_card_id: Option(Int),
) -> String {
  case selected_card_id {
    Some(card_id) ->
      case
        list.find(active_options(cards, depth_names), fn(option) {
          option.id == card_id
        })
      {
        Ok(option) -> option.label
        Error(_) -> ""
      }
    None -> ""
  }
}

pub fn search_value_to_card_id(
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
  value: String,
) -> String {
  let query = normalize(value)
  let matches =
    active_options(cards, depth_names)
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

fn option_for_card(
  card: Card,
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
) -> CardOption {
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

  CardOption(
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
