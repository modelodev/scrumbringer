import gleam/option.{None, Some}

import lustre/effect

import domain/api_error.{type ApiResult, ApiError}
import domain/card.{type Card, Card, Pendiente}
import domain/metrics.{
  type CardModalMetrics, CardModalMetrics, ModalExecutionHealth,
  WorkflowBreakdown,
}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/card_detail_update
import scrumbringer_client/features/pool/msg as pool_messages

fn local_model() -> card_detail_update.Model {
  card_detail_update.Model(
    pool: member_pool.default_model(),
    cards: admin_cards.default_model(),
  )
}

fn context() -> card_detail_update.Context(Nil) {
  card_detail_update.Context(
    on_card_marked: fn(_result: ApiResult(Nil)) { Nil },
    on_card_metrics_fetched: fn(_result: ApiResult(CardModalMetrics)) { Nil },
  )
}

fn sample_card(id: Int) -> Card {
  Card(
    id: id,
    project_id: 1,
    milestone_id: None,
    title: "Card",
    description: "",
    color: None,
    state: Pendiente,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    has_new_notes: True,
  )
}

fn metrics() -> CardModalMetrics {
  CardModalMetrics(
    tasks_total: 4,
    tasks_completed: 2,
    tasks_percent: 50,
    tasks_available: 1,
    tasks_claimed: 1,
    tasks_ongoing: 0,
    health: ModalExecutionHealth(
      avg_rebotes: 1,
      avg_pool_lifetime_s: 3600,
      avg_executors: 2,
    ),
    workflows: [WorkflowBreakdown(name: "Default", count: 1)],
    most_activated: None,
  )
}

pub fn card_detail_update_opened_updates_pool_cards_and_effects_test() {
  let model =
    card_detail_update.Model(
      ..local_model(),
      cards: admin_cards.Model(
        ..admin_cards.default_model(),
        cards: Loaded([sample_card(7), sample_card(9)]),
      ),
    )

  let #(next, fx) = card_detail_update.opened(model, 7, context())

  let assert Some(7) = next.pool.card_detail_open
  let assert Loading = next.pool.card_detail_metrics
  let assert Loaded([first, second]) = next.cards.cards
  let assert False = first.has_new_notes
  let assert True = second.has_new_notes
  let assert False = fx == effect.none()
}

pub fn card_detail_update_closed_clears_pool_detail_test() {
  let model =
    card_detail_update.Model(
      ..local_model(),
      pool: member_pool.Model(
        ..member_pool.default_model(),
        card_detail_open: Some(7),
        card_detail_metrics: Loaded(metrics()),
      ),
    )

  let #(next, fx) = card_detail_update.closed(model)

  let assert None = next.pool.card_detail_open
  let assert NotAsked = next.pool.card_detail_metrics
  let assert True = fx == effect.none()
}

pub fn card_detail_update_metrics_ok_sets_loaded_test() {
  let #(next, fx) =
    card_detail_update.metrics_fetched_ok(local_model(), metrics())

  let assert Loaded(loaded) = next.pool.card_detail_metrics
  let assert 4 = loaded.tasks_total
  let assert True = fx == effect.none()
}

pub fn card_detail_update_metrics_error_sets_failed_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")

  let #(next, fx) = card_detail_update.metrics_fetched_error(local_model(), err)

  let assert Failed(stored_err) = next.pool.card_detail_metrics
  let assert "boom" = stored_err.message
  let assert True = fx == effect.none()
}

pub fn card_detail_update_try_update_handles_open_message_test() {
  let assert Some(#(next, fx)) =
    card_detail_update.try_update(
      local_model(),
      pool_messages.OpenCardDetail(7),
      context(),
    )

  let assert Some(7) = next.pool.card_detail_open
  let assert Loading = next.pool.card_detail_metrics
  let assert False = fx == effect.none()
}

pub fn card_detail_update_try_update_ignores_non_detail_message_test() {
  let assert None =
    card_detail_update.try_update(
      local_model(),
      pool_messages.MemberPoolFiltersToggled,
      context(),
    )
}
