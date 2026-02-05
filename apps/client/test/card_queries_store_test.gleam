import gleam/option
import gleeunit/should

import domain/card.{type Card, Card, Pendiente}
import domain/remote.{NotAsked}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/state/normalized_store
import scrumbringer_client/utils/card_queries

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

pub fn find_card_uses_store_by_id_test() {
  let card_a = make_card(1, 10, "A")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a], card_id)

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_cards_store: store,
          member_cards: NotAsked,
        ),
      )
    })

  card_queries.find_card(model, 1) |> should.equal(option.Some(card_a))
}

pub fn get_project_cards_uses_store_index_test() {
  let card_a = make_card(1, 10, "A")
  let card_b = make_card(2, 10, "B")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a, card_b], card_id)

  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: option.Some(10))
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_cards_store: store),
      )
    })

  card_queries.get_project_cards(model) |> should.equal([card_a, card_b])
}

pub fn get_project_cards_ignores_missing_ids_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: option.Some(999))
    })

  card_queries.get_project_cards(model) |> should.equal([])
}
