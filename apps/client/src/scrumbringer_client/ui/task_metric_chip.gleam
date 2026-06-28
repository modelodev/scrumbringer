//// Shared task metric chip.

import gleam/int
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_metric.{type TaskMetric}
import scrumbringer_client/ui/tone

pub type Config {
  Config(
    locale: Locale,
    metric: TaskMetric,
    extra_class: Option(String),
    testid: Option(String),
  )
}

pub fn view(config: Config) -> Element(msg) {
  let title = task_metric.title(config.locale, config.metric)

  span(attrs(config, title), children(config.metric))
}

pub fn compact(locale: Locale, metric: TaskMetric) -> Element(msg) {
  view(Config(locale: locale, metric: metric, extra_class: None, testid: None))
}

fn attrs(config: Config, title: String) -> List(attribute.Attribute(msg)) {
  let class =
    "task-metric-chip "
    <> "is-compact "
    <> tone.class_name(task_metric.tone(config.metric.kind))
    <> " "
    <> task_metric.kind_key(config.metric.kind)

  let class = case config.extra_class {
    Some(extra) -> class <> " " <> extra
    None -> class
  }

  let testid = case config.testid {
    Some(value) -> value
    None -> task_metric.testid(config.metric.kind)
  }

  [
    attribute.class(class),
    attribute.attribute("data-testid", testid),
    attribute.attribute("title", title),
    attribute.attribute("aria-label", title),
  ]
}

fn children(metric: TaskMetric) -> List(Element(msg)) {
  let icon =
    span(
      [
        attribute.class("task-metric-chip-icon"),
        attribute.attribute("aria-hidden", "true"),
      ],
      [icons.nav_icon(task_metric.icon(metric.kind), icons.XSmall)],
    )

  let value =
    span([attribute.class("task-metric-chip-value")], [
      text(int.to_string(metric.value)),
    ])

  [icon, value]
}
