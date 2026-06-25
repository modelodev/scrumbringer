import gleam/option.{None, Some}

import domain/api_error.{ApiError}
import domain/card.{type Card, Card, Draft}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/card_refresh
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/state/normalized_store

pub fn loading_unless_loaded_preserves_loaded_cards_test() {
  let card = sample_card(1, 10)

  let assert Loaded([_card]) =
    card_refresh.loading_unless_loaded(Loaded([card]))
  let assert Loading = card_refresh.loading_unless_loaded(NotAsked)
  let assert Loading = card_refresh.loading_unless_loaded(Failed(api_error()))
}

pub fn project_fetched_updates_store_and_waits_until_ready_test() {
  let store =
    normalized_store.new()
    |> card_refresh.mark_pending(2)
  let card = sample_card(1, 10)

  let #(next_store, next_cards) =
    card_refresh.project_fetched(store, Loading, 10, [card])

  let assert 1 = normalized_store.pending(next_store)
  let assert Loading = next_cards
  let assert [_card] = normalized_store.get_by_project(next_store, 10)
}

pub fn project_fetched_returns_loaded_cards_when_all_projects_done_test() {
  let store =
    normalized_store.new()
    |> card_refresh.mark_pending(1)
  let card = sample_card(1, 10)

  let #(_next_store, next_cards) =
    card_refresh.project_fetched(store, Loading, 10, [card])

  let assert Loaded([_card]) = next_cards
}

pub fn project_failed_preserves_loaded_cards_and_fails_empty_state_test() {
  let card = sample_card(1, 10)

  let #(_loaded_store, loaded_cards) =
    card_refresh.project_failed(
      card_refresh.mark_pending(normalized_store.new(), 1),
      Loaded([card]),
      api_error(),
    )
  let #(_empty_store, empty_cards) =
    card_refresh.project_failed(
      card_refresh.mark_pending(normalized_store.new(), 1),
      Loading,
      api_error(),
    )

  let assert Loaded([_card]) = loaded_cards
  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    empty_cards
}

pub fn cards_fetched_updates_pool_card_store_and_resource_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_cards_store: card_refresh.mark_pending(normalized_store.new(), 1),
      member_cards: Loading,
    )

  let next = card_refresh.cards_fetched(pool, 10, [sample_card(1, 10)])

  let assert Loaded([Card(id: 1, ..)]) = next.member_cards
  let assert [Card(id: 1, ..)] =
    normalized_store.get_by_project(next.member_cards_store, 10)
}

pub fn cards_failed_updates_pool_card_store_and_preserves_loaded_cards_test() {
  let card = sample_card(1, 10)
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_cards_store: card_refresh.mark_pending(normalized_store.new(), 1),
      member_cards: Loaded([card]),
    )

  let next = card_refresh.cards_failed(pool, api_error())

  let assert Loaded([Card(id: 1, ..)]) = next.member_cards
  let assert 0 = normalized_store.pending(next.member_cards_store)
}

pub fn cards_failed_marks_unloaded_pool_cards_failed_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_cards_store: card_refresh.mark_pending(normalized_store.new(), 1),
      member_cards: Loading,
    )

  let next = card_refresh.cards_failed(pool, api_error())

  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    next.member_cards
  let assert 0 = normalized_store.pending(next.member_cards_store)
}

pub fn try_update_cards_fetched_returns_local_update_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_cards_store: card_refresh.mark_pending(normalized_store.new(), 1),
      member_cards: Loading,
    )

  let assert Some(next) =
    card_refresh.try_update(
      pool,
      pool_messages.MemberProjectCardsFetched(10, Ok([sample_card(1, 10)])),
    )

  let assert Loaded([Card(id: 1, ..)]) = next.member_cards
  let assert [Card(id: 1, ..)] =
    normalized_store.get_by_project(next.member_cards_store, 10)
}

pub fn try_update_cards_error_returns_local_update_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_cards_store: card_refresh.mark_pending(normalized_store.new(), 1),
      member_cards: Loading,
    )

  let assert Some(next) =
    card_refresh.try_update(
      pool,
      pool_messages.MemberProjectCardsFetched(10, Error(api_error())),
    )

  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    next.member_cards
  let assert 0 = normalized_store.pending(next.member_cards_store)
}

pub fn try_update_ignores_non_card_refresh_messages_test() {
  let assert None =
    card_refresh.try_update(
      member_pool.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
    )
}

fn api_error() {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn sample_card(id: Int, project_id: Int) -> Card {
  Card(
    id: id,
    project_id: project_id,
    parent_card_id: None,
    title: "Card",
    description: "",
    color: None,
    state: Draft,
    task_count: 0,
    closed_count: 0,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}
