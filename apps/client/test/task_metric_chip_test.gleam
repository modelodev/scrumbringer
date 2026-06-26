import gleam/option.{Some}
import gleam/string
import lustre/element

import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn full_task_metric_chip_renders_icon_value_label_and_accessibility_test() {
  let html =
    task_metric_chip.Config(
      locale: locale.En,
      metric: task_metric.metric(task_metric.Available, 4),
      variant: task_metric_chip.Full,
      extra_class: Some("work-surface-chip"),
      testid: Some("surface-available"),
    )
    |> task_metric_chip.view
    |> element.to_document_string

  assert_contains(html, "task-metric-chip is-full available")
  assert_contains(html, "work-surface-chip")
  assert_contains(html, "data-testid=\"surface-available\"")
  assert_contains(html, "title=\"Available: 4\"")
  assert_contains(html, "aria-label=\"Available: 4\"")
  assert_contains(html, "task-metric-chip-icon")
  assert_contains(html, "nav-icon")
  assert_contains(html, "task-metric-chip-value")
  assert_contains(html, ">4<")
  assert_contains(html, "task-metric-chip-label")
  assert_contains(html, ">Available<")
}

pub fn compact_task_metric_chip_hides_visible_label_but_keeps_meaning_test() {
  let html =
    task_metric_chip.compact(
      locale.En,
      task_metric.metric(task_metric.Blocked, 1),
    )
    |> element.to_document_string

  assert_contains(html, "task-metric-chip is-compact blocked")
  assert_contains(html, "data-testid=\"task-metric-blocked\"")
  assert_contains(html, "title=\"Blocked: 1\"")
  assert_contains(html, "aria-label=\"Blocked: 1\"")
  assert_contains(html, "task-metric-chip-icon")
  assert_contains(html, ">1<")
  assert_not_contains(html, "task-metric-chip-label")
  assert_not_contains(html, ">Blocked<")
}
