import gleam/option
import gleam/string
import lustre/element

import domain/card.{type Card, Card, Draft}
import domain/remote.{Loading}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/selectors as state_selectors
import scrumbringer_client/features/cards/view as cards_view
import scrumbringer_client/features/cards/view_config as cards_view_config
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/state/normalized_store
import scrumbringer_client/utils/card_queries

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

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

fn cards_config(model: client_state.Model) {
  cards_view_config.from_state(
    model.ui.locale,
    project_cards(model),
    model.member.pool,
    selected_detail_card(model),
    model.core.user,
    state_selectors.selected_project(model),
    fn(_) { "open" },
    fn(_) { "card-detail-msg" },
  )
}

fn selected_detail_card(model: client_state.Model) {
  case model.member.pool.card_detail_open {
    option.Some(card_id) -> find_card(model, card_id)
    option.None -> option.None
  }
}

fn find_card(model: client_state.Model, card_id: Int) {
  card_queries.find_card(
    model.member.pool.member_cards_store,
    model.admin.cards.cards,
    card_id,
  )
}

fn project_cards(model: client_state.Model) {
  card_queries.get_project_cards(
    model.member.pool.member_cards_store,
    model.admin.cards.cards,
    model.core.selected_project_id,
  )
}

pub fn cards_uses_cache_when_available_test() {
  let card_a = make_card(1, 10, "Card A")
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
    model
    |> cards_config
    |> cards_view.view_cards
    |> element.to_document_string

  assert_contains(html, "Card A")
}

pub fn cards_shows_loading_only_without_cache_test() {
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
    model
    |> cards_config
    |> cards_view.view_cards
    |> element.to_document_string

  let expected = i18n.t(model.ui.locale, i18n_text.LoadingEllipsis)
  assert_contains(html, expected)
}

pub fn cards_shows_empty_without_cache_or_pending_test() {
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
          member_cards_store: normalized_store.new(),
        ),
      )
    })

  let html =
    model
    |> cards_config
    |> cards_view.view_cards
    |> element.to_document_string

  let expected = i18n.t(model.ui.locale, i18n_text.MemberCardsEmpty)
  assert_contains(html, expected)
}
