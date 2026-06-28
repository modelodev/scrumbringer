import gleam/option.{Some}
import lustre/element
import support/render_assertions

import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip

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

  render_assertions.contains(html, "task-metric-chip is-full available")
  render_assertions.contains(html, "work-surface-chip")
  render_assertions.contains(html, "data-testid=\"surface-available\"")
  render_assertions.contains(html, "title=\"Available: 4\"")
  render_assertions.contains(html, "aria-label=\"Available: 4\"")
  render_assertions.contains(html, "task-metric-chip-icon")
  render_assertions.contains(html, "nav-icon")
  render_assertions.contains(html, "task-metric-chip-value")
  render_assertions.contains(html, ">4<")
  render_assertions.contains(html, "task-metric-chip-label")
  render_assertions.contains(html, ">Available<")
}

pub fn compact_task_metric_chip_hides_visible_label_but_keeps_meaning_test() {
  let html =
    task_metric_chip.compact(
      locale.En,
      task_metric.metric(task_metric.Blocked, 1),
    )
    |> element.to_document_string

  render_assertions.contains(html, "task-metric-chip is-compact blocked")
  render_assertions.contains(html, "data-testid=\"task-metric-blocked\"")
  render_assertions.contains(html, "title=\"Blocked: 1\"")
  render_assertions.contains(html, "aria-label=\"Blocked: 1\"")
  render_assertions.contains(html, "task-metric-chip-icon")
  render_assertions.contains(html, ">1<")
  render_assertions.not_contains(html, "task-metric-chip-label")
  render_assertions.not_contains(html, ">Blocked<")
}
