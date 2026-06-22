import gleam/int
import gleam/option.{None, Some}

import lustre/effect

import api/cards/contracts as card_contracts
import domain/api_error.{type ApiResult}
import domain/card.{type Card, Card, Draft}
import domain/remote.{Loaded}
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/card_show_update
import scrumbringer_client/features/pool/msg as pool_messages

fn local_model() -> card_show_update.Model {
  card_show_update.Model(
    pool: member_pool.default_model(),
    cards: admin_cards.default_model(),
  )
}

fn context() -> card_show_update.Context(Nil) {
  card_show_update.Context(
    on_card_marked: fn(_result: ApiResult(Nil)) { Nil },
    on_card_show_msg: fn(_msg) { Nil },
    on_card_activated: fn(_result: ApiResult(card_contracts.CardActionResponse)) {
      Nil
    },
    on_create_task: fn(_card_id) { Nil },
    on_create_card: fn(_card_id) { Nil },
    on_activate_card: fn(_card_id) { Nil },
    on_move_card: fn(_card_id) { Nil },
    on_delete_card: fn(_card_id) { Nil },
    on_close: Nil,
    on_success_toast: fn(_message) { effect.none() },
    on_error_toast: fn(_message) { effect.none() },
    hierarchy_activated: "Hierarchy activated",
    hierarchy_pool_impact: fn(pool_impact) {
      "Al activar " <> int.to_string(pool_impact)
    },
    hierarchy_pool_saturated: fn(pool_open_after, healthy_pool_limit) {
      "Pool at "
      <> int.to_string(pool_open_after)
      <> "/"
      <> int.to_string(healthy_pool_limit)
    },
    hierarchy_activate_failed: "Could not activate hierarchy",
  )
}

fn context_with_toasts() -> card_show_update.Context(Nil) {
  card_show_update.Context(
    ..context(),
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn sample_card(id: Int) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: None,
    title: "Card",
    description: "",
    color: None,
    state: Draft,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: True,
  )
}

pub fn card_show_update_opened_updates_pool_cards_and_effects_test() {
  let model =
    card_show_update.Model(
      ..local_model(),
      cards: admin_cards.Model(
        ..admin_cards.default_model(),
        cards: Loaded([sample_card(7), sample_card(9)]),
      ),
    )

  let assert Some(#(next, fx)) =
    card_show_update.try_update(model, pool_messages.OpenCardShow(7), context())

  let assert Some(7) = next.pool.card_show_open
  let assert Loaded([first, second]) = next.cards.cards
  let assert False = first.has_new_notes
  let assert True = second.has_new_notes
  let assert False = fx == effect.none()
}

pub fn card_show_update_closed_clears_pool_show_test() {
  let model =
    card_show_update.Model(
      ..local_model(),
      pool: member_pool.Model(
        ..member_pool.default_model(),
        card_show_open: Some(7),
      ),
    )

  let assert Some(#(next, fx)) =
    card_show_update.try_update(model, pool_messages.CloseCardShow, context())

  let assert None = next.pool.card_show_open
  let assert True = fx == effect.none()
}

pub fn card_show_update_activate_requested_submits_effect_test() {
  let assert Some(#(next, fx)) =
    card_show_update.try_update(
      local_model(),
      pool_messages.CardActivateRequested(7),
      context(),
    )

  let assert True = next.pool == member_pool.default_model()
  let assert False = fx == effect.none()
}

pub fn card_show_update_activated_ok_shows_feedback_test() {
  let response =
    card_contracts.CardActionResponse(
      card_id: 7,
      pool_impact: 3,
      pool_open_after: 8,
      healthy_pool_limit: 10,
      pool_health: card_contracts.PoolWithinHealthyLimit,
    )

  let assert Some(#(_next, fx)) =
    card_show_update.try_update(
      local_model(),
      pool_messages.CardActivated(Ok(response)),
      context_with_toasts(),
    )

  let assert False = fx == effect.none()
}

pub fn card_show_update_try_update_handles_open_message_test() {
  let assert Some(#(next, fx)) =
    card_show_update.try_update(
      local_model(),
      pool_messages.OpenCardShow(7),
      context(),
    )

  let assert Some(7) = next.pool.card_show_open
  let assert False = fx == effect.none()
}

pub fn card_show_update_try_update_ignores_non_card_show_message_test() {
  let assert None =
    card_show_update.try_update(
      local_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      context(),
    )
}
