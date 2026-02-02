import gleam/list
import gleam/option
import gleeunit/should

import domain/card.{type Card, Card, Pendiente}
import scrumbringer_client/state/normalized_store

fn make_card(id: Int, project_id: Int, title: String) -> Card {
  Card(
    id: id,
    project_id: project_id,
    title: title,
    description: "",
    color: option.None,
    state: Pendiente,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-02-01T00:00:00Z",
    has_new_notes: False,
  )
}

fn card_id(card: Card) -> Int {
  let Card(id: id, ..) = card
  id
}

pub fn upsert_deduplicates_by_id_test() {
  let card_a = make_card(1, 10, "A")
  let card_b = make_card(1, 10, "B")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a, card_b], card_id)

  let cards = normalized_store.get_by_project(store, 10)
  list.length(cards) |> should.equal(1)
}

pub fn upsert_empty_list_no_changes_test() {
  let card_a = make_card(1, 10, "A")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a], card_id)

  let next = normalized_store.upsert(store, 10, [], card_id)

  normalized_store.get_by_project(next, 10)
  |> should.equal(normalized_store.get_by_project(store, 10))
}

pub fn to_list_preserves_project_order_test() {
  let card_a = make_card(1, 10, "A")
  let card_b = make_card(2, 10, "B")
  let card_c = make_card(3, 20, "C")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a, card_b], card_id)
    |> normalized_store.upsert(20, [card_c], card_id)

  normalized_store.to_list(store) |> should.equal([card_a, card_b, card_c])
}

pub fn to_list_skips_missing_ids_test() {
  let store = normalized_store.new()
  normalized_store.to_list(store) |> should.equal([])
}

pub fn get_by_project_ignores_missing_ids_test() {
  let store = normalized_store.new()
  normalized_store.get_by_project(store, 999) |> should.equal([])
}
