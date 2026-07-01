//// Shared card read model.
////
//// Centralises the client-side precedence for card reads: member cache first,
//// admin cards fallback. Views receive this projection instead of knowing
//// where cards are stored.

import gleam/option as opt

import domain/card.{type Card}
import domain/remote.{type Remote}
import scrumbringer_client/state/normalized_store.{type NormalizedStore}
import scrumbringer_client/utils/card_queries

pub type ReadModel {
  ReadModel(
    find_card: fn(Int) -> opt.Option(Card),
    project_cards: fn() -> List(Card),
  )
}

pub fn from_sources(
  member_cards_store: NormalizedStore(Int, Card),
  admin_cards: Remote(List(Card)),
  selected_project_id: opt.Option(Int),
) -> ReadModel {
  ReadModel(
    find_card: fn(card_id) {
      card_queries.find_card(member_cards_store, admin_cards, card_id)
    },
    project_cards: fn() {
      card_queries.get_project_cards(
        member_cards_store,
        admin_cards,
        selected_project_id,
      )
    },
  )
}

pub fn find_card(read_model: ReadModel, card_id: Int) -> opt.Option(Card) {
  read_model.find_card(card_id)
}

pub fn project_cards(read_model: ReadModel) -> List(Card) {
  read_model.project_cards()
}
