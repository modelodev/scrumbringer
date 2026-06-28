import gleam/option as opt

import lustre/element

import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip

pub fn task_metric(
  locale: Locale,
  kind: task_metric.TaskMetricKind,
  value: Int,
) -> element.Element(msg) {
  task_metric_chip.view(task_metric_chip.Config(
    locale: locale,
    metric: task_metric.metric(kind, value),
    extra_class: opt.Some("assignments-task-metric"),
    testid: opt.None,
  ))
}
