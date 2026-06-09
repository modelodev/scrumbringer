import gleam/option.{None, Some}

import domain/api_error.{ApiError}
import domain/metrics.{CardModalMetrics, ModalExecutionHealth, WorkflowBreakdown}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/card_detail

fn default_pool() -> member_pool.Model {
  member_pool.default_model()
}

fn metrics() {
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

pub fn card_detail_opened_sets_selected_card_and_loads_metrics_test() {
  let pool = card_detail.handle_opened(default_pool(), 42)

  let assert Some(42) = pool.card_detail_open
  let assert Loading = pool.card_detail_metrics
}

pub fn card_detail_closed_clears_selection_and_metrics_test() {
  let pool =
    member_pool.Model(
      ..default_pool(),
      card_detail_open: Some(42),
      card_detail_metrics: Loaded(metrics()),
    )

  let next = card_detail.handle_closed(pool)

  let assert None = next.card_detail_open
  let assert NotAsked = next.card_detail_metrics
}

pub fn card_detail_metrics_ok_stores_loaded_metrics_test() {
  let card_metrics = metrics()
  let pool = card_detail.handle_metrics_fetched_ok(default_pool(), card_metrics)

  let assert Loaded(loaded_metrics) = pool.card_detail_metrics
  let assert 4 = loaded_metrics.tasks_total
}

pub fn card_detail_metrics_error_stores_failed_error_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let pool = card_detail.handle_metrics_fetched_error(default_pool(), err)

  let assert Failed(stored_err) = pool.card_detail_metrics
  let assert "boom" = stored_err.message
}
