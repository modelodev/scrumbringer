import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/api_error.{ApiError}
import domain/metrics.{type TaskModalMetrics, TaskModalMetrics}
import domain/remote
import scrumbringer_client/features/pool/task_metrics
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn task_metrics_renders_loading_state_test() {
  let html =
    task_metrics.view(task_metrics.Config(
      locale: locale.En,
      metrics: remote.Loading,
    ))
    |> element.to_document_string

  assert_contains(html, "task-metrics-empty")
  assert_contains(html, "Loading metrics")
  assert_not_contains(html, "task-metrics-grid")
}

pub fn task_metrics_renders_error_state_test() {
  let html =
    task_metrics.view(task_metrics.Config(
      locale: locale.En,
      metrics: remote.Failed(ApiError(
        status: 500,
        code: "metrics_error",
        message: "Metrics unavailable",
      )),
    ))
    |> element.to_document_string

  assert_contains(html, "task-metrics-empty")
  assert_contains(html, "Could not load metrics")
  assert_not_contains(html, "task-metrics-grid")
}

pub fn task_metrics_renders_empty_loaded_state_test() {
  let html =
    task_metrics.view(task_metrics.Config(
      locale: locale.Es,
      metrics: remote.Loaded(empty_metrics()),
    ))
    |> element.to_document_string

  assert_contains(html, "task-metrics-empty")
  assert_contains(html, "Sin datos suficientes para métricas")
  assert_not_contains(html, "task-metrics-grid")
}

pub fn task_metrics_renders_metrics_grid_test() {
  let html =
    task_metrics.view(task_metrics.Config(
      locale: locale.En,
      metrics: remote.Loaded(TaskModalMetrics(
        claim_count: 2,
        release_count: 1,
        unique_executors: 3,
        first_claim_at: Some("2026-06-08T09:30:00Z"),
        current_state_duration_s: 3661,
        pool_lifetime_s: 61,
        session_count: 4,
        total_work_time_s: 59,
      )),
    ))
    |> element.to_document_string

  assert_contains(html, "task-metrics-grid")
  assert_contains(html, "Claim count")
  assert_contains(html, "Release count")
  assert_contains(html, "Unique executors")
  assert_contains(html, "First claim at")
  assert_contains(html, "2026-06-08T09:30:00Z")
  assert_contains(html, "Current state time")
  assert_contains(html, "1h 1m")
  assert_contains(html, "Pool lifetime")
  assert_contains(html, "1m 1s")
  assert_contains(html, "Session count")
  assert_contains(html, "Total work time")
  assert_contains(html, "59s")
}

fn empty_metrics() -> TaskModalMetrics {
  TaskModalMetrics(
    claim_count: 0,
    release_count: 0,
    unique_executors: 0,
    first_claim_at: None,
    current_state_duration_s: 0,
    pool_lifetime_s: 0,
    session_count: 0,
    total_work_time_s: 0,
  )
}
