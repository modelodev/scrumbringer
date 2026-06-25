//// Pure visible-tree helpers for Plan structure rows.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/card.{type Card}

pub fn nearest_visible_parent_id(
  card: Card,
  visible_cards: List(Card),
  all_cards: List(Card),
) -> Option(Int) {
  nearest_visible_parent_id_from(
    card.parent_card_id,
    list.map(visible_cards, fn(visible_card) { visible_card.id }),
    all_cards,
  )
}

fn nearest_visible_parent_id_from(
  parent_id: Option(Int),
  visible_ids: List(Int),
  all_cards: List(Card),
) -> Option(Int) {
  case parent_id {
    None -> None
    Some(id) ->
      case list.contains(visible_ids, id) {
        True -> Some(id)
        False ->
          case list.find(all_cards, fn(card) { card.id == id }) {
            Ok(parent) ->
              nearest_visible_parent_id_from(
                parent.parent_card_id,
                visible_ids,
                all_cards,
              )
            Error(_) -> None
          }
      }
  }
}
