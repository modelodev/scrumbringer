//// Pure Card Show hierarchy helpers.

import gleam/list
import gleam/option

import domain/card.{type Card}

pub fn affected_card_count(card: Card, cards: List(Card)) -> Int {
  1
  + list.length(
    list.filter(cards, fn(candidate) {
      is_descendant_of(candidate, card, cards)
    }),
  )
}

fn is_descendant_of(candidate: Card, ancestor: Card, cards: List(Card)) -> Bool {
  case candidate.parent_card_id {
    option.Some(parent_id) if parent_id == ancestor.id -> True
    option.Some(parent_id) ->
      case find_card_by_id(cards, parent_id) {
        option.Some(parent) -> is_descendant_of(parent, ancestor, cards)
        option.None -> False
      }
    option.None -> False
  }
}

fn find_card_by_id(cards: List(Card), card_id: Int) -> option.Option(Card) {
  case list.find(cards, fn(card) { card.id == card_id }) {
    Ok(card) -> option.Some(card)
    Error(_) -> option.None
  }
}

pub fn path_labels(cards: List(Card), card: Card) -> List(String) {
  card_path(cards, card)
  |> list.map(fn(path_card) { path_card.title })
}

fn card_path(cards: List(Card), card: Card) -> List(Card) {
  collect_path(cards, card, [])
}

fn collect_path(
  cards: List(Card),
  card: Card,
  collected: List(Card),
) -> List(Card) {
  let next = [card, ..collected]

  case card.parent_card_id {
    option.Some(parent_id) ->
      case find_card_by_id(cards, parent_id) {
        option.Some(parent) -> collect_path(cards, parent, next)
        option.None -> next
      }
    option.None -> next
  }
}
