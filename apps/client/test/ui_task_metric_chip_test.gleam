import gleam/option
import gleam/string

import lustre/element

import scrumbringer_client/i18n/locale.{En}
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip

fn render(variant: task_metric_chip.Variant) -> String {
  task_metric_chip.view(task_metric_chip.Config(
    locale: En,
    metric: task_metric.metric(task_metric.Closed, 3),
    variant: variant,
    extra_class: option.None,
    testid: option.Some("metric-under-test"),
  ))
  |> element.to_document_string
}

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn compact_metric_keeps_icon_number_and_accessible_label_test() {
  let html = render(task_metric_chip.Compact)

  assert_contains(html, "is-compact")
  assert_contains(html, "metric-under-test")
  assert_contains(html, "task-metric-chip-icon")
  assert_contains(html, "task-metric-chip-value")
  assert_contains(html, ">3<")
  assert_contains(html, "title=\"Closed: 3\"")
  assert_contains(html, "aria-label=\"Closed: 3\"")
  assert_not_contains(html, "task-metric-chip-label")
}

pub fn full_metric_keeps_visible_label_for_explicit_explanatory_use_test() {
  let html = render(task_metric_chip.Full)

  assert_contains(html, "is-full")
  assert_contains(html, "task-metric-chip-label")
  assert_contains(html, ">Closed<")
}
