import gleam/option.{None}
import gleam/string
import lustre/element

import domain/api_error.{ApiError}
import domain/metrics.{
  MilestoneModalMetrics, ModalExecutionHealth, WorkflowBreakdown,
}
import domain/remote.{Failed, Loaded, Loading}
import scrumbringer_client/features/milestones/metrics_summary
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn metrics() {
  MilestoneModalMetrics(
    cards_total: 5,
    cards_completed: 3,
    cards_percent: 60,
    tasks_total: 8,
    tasks_completed: 4,
    tasks_percent: 50,
    tasks_available: 2,
    tasks_claimed: 1,
    tasks_ongoing: 1,
    health: ModalExecutionHealth(
      avg_rebotes: 2,
      avg_pool_lifetime_s: 3600,
      avg_executors: 1,
    ),
    workflows: [WorkflowBreakdown(name: "Default", count: 1)],
    most_activated: None,
  )
}

fn view(metrics_remote) {
  metrics_summary.view(metrics_summary.Config(
    locale: locale.En,
    metrics: metrics_remote,
  ))
  |> element.to_document_string
}

pub fn milestones_metrics_summary_renders_loading_without_root_model_test() {
  let html = view(Loading)

  assert_contains(html, "Loading metrics")
}

pub fn milestones_metrics_summary_renders_error_without_root_model_test() {
  let html = view(Failed(ApiError(status: 500, code: "ERR", message: "boom")))

  assert_contains(html, "Could not load metrics")
}

pub fn milestones_metrics_summary_renders_loaded_metrics_without_root_model_test() {
  let html = view(Loaded(metrics()))

  assert_contains(html, "Cards")
  assert_contains(html, "3/5")
  assert_contains(html, "Tasks")
  assert_contains(html, "4/8")
  assert_contains(html, "Average pool lifetime")
  assert_contains(html, "1h")
  assert_contains(html, "Average bounces")
  assert_contains(html, "2")
}
