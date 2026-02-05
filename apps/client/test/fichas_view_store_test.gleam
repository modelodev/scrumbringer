import gleam/option
import gleam/string
import gleeunit/should
import lustre/element

import domain/card.{type Card, Card, Pendiente}
import domain/remote.{Loading}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/fichas/view as fichas_view
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
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

pub fn fichas_uses_cache_when_available_test() {
  let card_a = make_card(1, 10, "Ficha A")
  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a], card_id)

  let model =
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
          member_cards: Loading,
        ),
      )
    })

  let html =
    fichas_view.view_fichas(model)
    |> element.to_document_string

  string.contains(html, "Ficha A") |> should.be_true
}

pub fn fichas_shows_loading_only_without_cache_test() {
  let store = normalized_store.new() |> normalized_store.with_pending(1)

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

  let html =
    fichas_view.view_fichas(model)
    |> element.to_document_string

  let expected = helpers_i18n.i18n_t(model, i18n_text.LoadingEllipsis)
  string.contains(html, expected) |> should.be_true
}

pub fn fichas_shows_empty_without_cache_or_pending_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: option.Some(10))
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_cards_store: normalized_store.new()),
      )
    })

  let html =
    fichas_view.view_fichas(model)
    |> element.to_document_string

  let expected = helpers_i18n.i18n_t(model, i18n_text.MemberFichasEmpty)
  string.contains(html, expected) |> should.be_true
}
