import domain/api_error.{type ApiError, ApiError}
import domain/card.{type Card, Card, Pendiente}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import gleam/option
import gleeunit/should
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_update
import scrumbringer_client/features/pool/msg as pool_messages
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

fn api_error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn base_model_with_store(
  store: normalized_store.NormalizedStore(Int, Card),
) -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(..core, selected_project_id: option.Some(10))
  })
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
}

pub fn member_project_cards_ok_updates_store_and_pending_test() {
  let store = normalized_store.new() |> normalized_store.with_pending(1)
  let model = base_model_with_store(store)
  let card_a = make_card(1, 10, "A")

  let #(next, _fx) =
    client_update.update(
      model,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        10,
        Ok([card_a]),
      )),
    )

  normalized_store.get_by_project(next.member.pool.member_cards_store, 10)
  |> should.equal([card_a])
  normalized_store.pending(next.member.pool.member_cards_store)
  |> should.equal(0)
}

pub fn member_project_cards_error_preserves_store_test() {
  let card_a = make_card(1, 10, "A")
  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a], card_id)
    |> normalized_store.with_pending(1)

  let model = base_model_with_store(store)

  let #(next, _fx) =
    client_update.update(
      model,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        10,
        Error(api_error()),
      )),
    )

  normalized_store.get_by_project(next.member.pool.member_cards_store, 10)
  |> should.equal([card_a])
  next.member.pool.member_cards |> should.equal(Failed(api_error()))
}

pub fn pending_never_below_zero_test() {
  let store = normalized_store.new() |> normalized_store.with_pending(0)
  let model = base_model_with_store(store)
  let card_a = make_card(1, 10, "A")

  let #(next, _fx) =
    client_update.update(
      model,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        10,
        Ok([card_a]),
      )),
    )

  normalized_store.pending(next.member.pool.member_cards_store)
  |> should.equal(0)
}

pub fn late_project_response_keeps_other_project_index_test() {
  let store = normalized_store.new() |> normalized_store.with_pending(2)
  let model = base_model_with_store(store)

  let card_b = make_card(2, 20, "B")
  let card_a = make_card(1, 10, "A")

  let #(next_b, _fx_b) =
    client_update.update(
      model,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        20,
        Ok([card_b]),
      )),
    )

  let #(next_a, _fx_a) =
    client_update.update(
      next_b,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        10,
        Ok([card_a]),
      )),
    )

  normalized_store.get_by_project(next_a.member.pool.member_cards_store, 20)
  |> should.equal([card_b])
}

pub fn partial_error_keeps_global_loaded_test() {
  let card_a = make_card(1, 10, "A")
  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a], card_id)
    |> normalized_store.with_pending(1)

  let model =
    base_model_with_store(store)
    |> client_state.update_member(fn(member) {
      let pool = member.pool

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_cards: Loaded([card_a])),
      )
    })

  let #(next, _fx) =
    client_update.update(
      model,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        10,
        Error(api_error()),
      )),
    )

  next.member.pool.member_cards |> should.equal(Loaded([card_a]))
}

pub fn pending_counts_across_multi_project_refresh_test() {
  let store = normalized_store.new() |> normalized_store.with_pending(2)
  let model = base_model_with_store(store)
  let card_a = make_card(1, 10, "A")

  let #(next_a, _fx_a) =
    client_update.update(
      model,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        10,
        Ok([card_a]),
      )),
    )

  normalized_store.pending(next_a.member.pool.member_cards_store)
  |> should.equal(1)

  let #(next_b, _fx_b) =
    client_update.update(
      next_a,
      client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
        20,
        Error(api_error()),
      )),
    )

  normalized_store.pending(next_b.member.pool.member_cards_store)
  |> should.equal(0)
  next_b.member.pool.member_cards |> should.not_equal(Loading)
}
