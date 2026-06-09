//// Pure member-card refresh derivations for multi-project fetches.

import gleam/option as opt

import domain/api_error.{type ApiError}
import domain/card.{type Card, Card}
import domain/remote.{type Remote, Failed, Loaded, Loading}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/state/normalized_store as store

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(member_pool.Model) {
  case inner {
    pool_messages.MemberProjectCardsFetched(project_id, Ok(cards)) ->
      cards_fetched(model, project_id, cards)
      |> opt.Some

    pool_messages.MemberProjectCardsFetched(_project_id, Error(err)) ->
      cards_failed(model, err)
      |> opt.Some

    _ -> opt.None
  }
}

pub fn mark_pending(
  cards_store: store.NormalizedStore(Int, Card),
  project_count: Int,
) -> store.NormalizedStore(Int, Card) {
  store.with_pending(cards_store, project_count)
}

pub fn loading_unless_loaded(cards: Remote(List(Card))) -> Remote(List(Card)) {
  case cards {
    Loaded(_) -> cards
    _ -> Loading
  }
}

pub fn project_fetched(
  cards_store: store.NormalizedStore(Int, Card),
  current: Remote(List(Card)),
  project_id: Int,
  cards: List(Card),
) -> #(store.NormalizedStore(Int, Card), Remote(List(Card))) {
  let next_store =
    cards_store
    |> store.upsert(project_id, cards, card_id)
    |> store.decrement_pending
  let next_cards = case store.is_ready(next_store) {
    True -> Loaded(store.to_list(next_store))
    False -> current
  }

  #(next_store, next_cards)
}

pub fn project_failed(
  cards_store: store.NormalizedStore(Int, Card),
  current: Remote(List(Card)),
  err: ApiError,
) -> #(store.NormalizedStore(Int, Card), Remote(List(Card))) {
  let next_store = store.decrement_pending(cards_store)
  let next_cards = case current {
    Loaded(_) -> current
    _ -> Failed(err)
  }

  #(next_store, next_cards)
}

pub fn cards_fetched(
  model: member_pool.Model,
  project_id: Int,
  cards: List(Card),
) -> member_pool.Model {
  let #(next_store, next_cards) =
    project_fetched(
      model.member_cards_store,
      model.member_cards,
      project_id,
      cards,
    )

  member_pool.Model(
    ..model,
    member_cards_store: next_store,
    member_cards: next_cards,
  )
}

pub fn cards_failed(
  model: member_pool.Model,
  err: ApiError,
) -> member_pool.Model {
  let #(next_store, next_cards) =
    project_failed(model.member_cards_store, model.member_cards, err)

  member_pool.Model(
    ..model,
    member_cards_store: next_store,
    member_cards: next_cards,
  )
}

fn card_id(card: Card) -> Int {
  let Card(id: id, ..) = card
  id
}
