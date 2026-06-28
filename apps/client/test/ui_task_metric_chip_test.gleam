import gleam/option
import support/render_assertions

import scrumbringer_client/i18n/locale.{En}
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip

fn render() -> String {
  task_metric_chip.view(task_metric_chip.Config(
    locale: En,
    metric: task_metric.metric(task_metric.Closed, 3),
    extra_class: option.None,
    testid: option.Some("metric-under-test"),
  ))
  |> render_assertions.html
}

pub fn compact_metric_keeps_icon_number_and_accessible_label_test() {
  let html = render()

  render_assertions.contains(html, "is-compact")
  render_assertions.contains(html, "metric-under-test")
  render_assertions.contains(html, "task-metric-chip-icon")
  render_assertions.contains(html, "task-metric-chip-value")
  render_assertions.contains(html, ">3<")
  render_assertions.contains(html, "title=\"Closed: 3\"")
  render_assertions.contains(html, "aria-label=\"Closed: 3\"")
  render_assertions.not_contains(html, "task-metric-chip-label")
}
