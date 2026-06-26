//// Local card cache projections.
////
//// Applies confirmed card CRUD events to client-side card projections so
//// selectors and views do not depend on a full page reload after mutations.

import gleam/list
import gleam/option as opt

import domain/card.{type Card, Card}
import domain/remote.{type Remote, Loaded}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/state/normalized_store

pub fn created(model: member_pool.Model, card: Card) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_cards_store: normalized_store.upsert_one(
      model.member_cards_store,
      card.project_id,
      card,
      card_id,
    ),
    member_cards: upsert_remote(model.member_cards, card),
  )
}

pub fn updated(model: member_pool.Model, card: Card) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_cards_store: normalized_store.upsert_one(
      model.member_cards_store,
      card.project_id,
      card,
      card_id,
    ),
    member_cards: upsert_remote(model.member_cards, card),
  )
}

pub fn deleted(model: member_pool.Model, deleted_id: Int) -> member_pool.Model {
  let project_id = project_id_for_delete(model, deleted_id)

  let next_store = case project_id {
    opt.Some(id) ->
      normalized_store.remove_one(model.member_cards_store, id, deleted_id)
    opt.None -> model.member_cards_store
  }

  member_pool.Model(
    ..model,
    member_cards_store: next_store,
    member_cards: remove_from_remote(model.member_cards, deleted_id),
  )
}

fn upsert_remote(cards: Remote(List(Card)), card: Card) -> Remote(List(Card)) {
  case cards {
    Loaded(existing) -> Loaded(upsert_list(existing, card))
    other -> other
  }
}

fn remove_from_remote(
  cards: Remote(List(Card)),
  deleted_id: Int,
) -> Remote(List(Card)) {
  case cards {
    Loaded(existing) ->
      Loaded(list.filter(existing, fn(card) { card.id != deleted_id }))
    other -> other
  }
}

fn upsert_list(cards: List(Card), card: Card) -> List(Card) {
  case list.any(cards, fn(existing) { existing.id == card.id }) {
    True ->
      list.map(cards, fn(existing) {
        case existing.id == card.id {
          True -> card
          False -> existing
        }
      })
    False -> [card, ..cards]
  }
}

fn project_id_for_delete(
  model: member_pool.Model,
  deleted_id: Int,
) -> opt.Option(Int) {
  case normalized_store.get_by_id(model.member_cards_store, deleted_id) {
    opt.Some(card) -> opt.Some(card.project_id)
    opt.None ->
      case model.member_cards {
        Loaded(cards) ->
          case list.find(cards, fn(card) { card.id == deleted_id }) {
            Ok(card) -> opt.Some(card.project_id)
            Error(_) -> opt.None
          }
        _ -> opt.None
      }
  }
}

fn card_id(card: Card) -> Int {
  let Card(id: id, ..) = card
  id
}
