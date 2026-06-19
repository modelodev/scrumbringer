import gleam/option

import domain/card.{type Card, Card, Draft}
import domain/remote.{Loaded, NotAsked}
import scrumbringer_client/state/normalized_store
import scrumbringer_client/utils/card_queries

fn make_card(id: Int, project_id: Int, title: String) -> Card {
  Card(
    id: id,
    project_id: project_id,
    parent_card_id: option.None,
    title: title,
    description: "",
    color: option.None,
    state: Draft,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-02-01T00:00:00Z",
    due_date: option.None,
    has_new_notes: False,
  )
}

fn card_id(card: Card) -> Int {
  let Card(id: id, ..) = card
  id
}

pub fn find_card_uses_store_by_id_test() {
  let card_a = make_card(1, 10, "A")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a], card_id)

  let assert True =
    card_queries.find_card(store, NotAsked, 1) == option.Some(card_a)
}

pub fn get_project_cards_uses_store_index_test() {
  let card_a = make_card(1, 10, "A")
  let card_b = make_card(2, 10, "B")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a, card_b], card_id)

  let assert True =
    card_queries.get_project_cards(store, Loaded([]), option.Some(10))
    == [card_a, card_b]
}

pub fn get_project_cards_ignores_missing_ids_test() {
  let assert [] =
    card_queries.get_project_cards(
      normalized_store.new(),
      NotAsked,
      option.Some(999),
    )
}
