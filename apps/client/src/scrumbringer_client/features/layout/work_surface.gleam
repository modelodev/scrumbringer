//// Shared composition for member work surfaces.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{div, h3, p, text}

import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip
import scrumbringer_client/ui/tone

pub type SummaryChip {
  SummaryChip(label: String, value: String, tone: tone.Tone)
  TaskSummaryChip(locale: Locale, metric: task_metric.TaskMetric)
}

pub type HeaderConfig(msg) {
  HeaderConfig(
    title: String,
    purpose: String,
    summary: List(SummaryChip),
    actions: List(Element(msg)),
    extra_class: Option(String),
    testid: Option(String),
  )
}

pub type SurfaceConfig(msg) {
  SurfaceConfig(
    header: Element(msg),
    filters: Option(Element(msg)),
    content: Option(Element(msg)),
    state: Option(Element(msg)),
    extra_class: Option(String),
    testid: Option(String),
  )
}

pub fn header(config: HeaderConfig(msg)) -> Element(msg) {
  div(header_attrs(config), [
    div([attribute.class("work-surface-copy")], [
      h3([attribute.class("work-surface-title")], [text(config.title)]),
      p([attribute.class("work-surface-purpose")], [text(config.purpose)]),
    ]),
    div([attribute.class("work-surface-meta")], [
      view_summary(config.summary),
      view_actions(config.actions),
    ]),
  ])
}

pub fn surface(config: SurfaceConfig(msg)) -> Element(msg) {
  div(surface_attrs(config), [
    div([attribute.class("work-surface-chrome")], [
      config.header,
      optional_slot("work-surface-filters", config.filters),
    ]),
    optional_slot("work-surface-state", config.state),
    optional_slot("work-surface-content", config.content),
  ])
}

pub fn summary_chip(
  label: String,
  value: String,
  tone_value: tone.Tone,
) -> SummaryChip {
  SummaryChip(label: label, value: value, tone: tone_value)
}

pub fn task_summary_chip(
  locale: Locale,
  kind: task_metric.TaskMetricKind,
  value: Int,
) -> SummaryChip {
  TaskSummaryChip(locale: locale, metric: task_metric.metric(kind, value))
}

pub fn with_filters(
  config: SurfaceConfig(msg),
  filters: Element(msg),
) -> SurfaceConfig(msg) {
  SurfaceConfig(..config, filters: Some(filters))
}

pub fn with_content(
  config: SurfaceConfig(msg),
  content: Element(msg),
) -> SurfaceConfig(msg) {
  SurfaceConfig(..config, content: Some(content))
}

pub fn with_state(
  config: SurfaceConfig(msg),
  state: Element(msg),
) -> SurfaceConfig(msg) {
  SurfaceConfig(..config, state: Some(state))
}

pub fn new_surface(header: Element(msg)) -> SurfaceConfig(msg) {
  SurfaceConfig(
    header:,
    filters: None,
    content: None,
    state: None,
    extra_class: None,
    testid: None,
  )
}

pub fn surface_with_class(
  config: SurfaceConfig(msg),
  extra_class: String,
) -> SurfaceConfig(msg) {
  SurfaceConfig(..config, extra_class: Some(extra_class))
}

pub fn surface_with_testid(
  config: SurfaceConfig(msg),
  testid: String,
) -> SurfaceConfig(msg) {
  SurfaceConfig(..config, testid: Some(testid))
}

fn header_attrs(config: HeaderConfig(msg)) -> List(attribute.Attribute(msg)) {
  let class = case config.extra_class {
    Some(extra) -> "work-surface-header " <> extra
    None -> "work-surface-header"
  }

  list.append([attribute.class(class)], case config.testid {
    Some(value) -> [attribute.attribute("data-testid", value)]
    None -> []
  })
}

fn surface_attrs(config: SurfaceConfig(msg)) -> List(attribute.Attribute(msg)) {
  let class = case config.extra_class {
    Some(extra) -> "work-surface " <> extra
    None -> "work-surface"
  }

  list.append([attribute.class(class)], case config.testid {
    Some(value) -> [attribute.attribute("data-testid", value)]
    None -> []
  })
}

fn optional_slot(class_name: String, slot: Option(Element(msg))) -> Element(msg) {
  case slot {
    Some(content) -> div([attribute.class(class_name)], [content])
    None -> none()
  }
}

fn view_summary(summary: List(SummaryChip)) -> Element(msg) {
  case summary {
    [] -> div([attribute.class("work-surface-summary is-empty")], [])
    _ ->
      div(
        [attribute.class("work-surface-summary")],
        list.map(summary, view_summary_chip),
      )
  }
}

fn view_actions(actions: List(Element(msg))) -> Element(msg) {
  case actions {
    [] -> div([attribute.class("work-surface-actions is-empty")], [])
    _ -> div([attribute.class("work-surface-actions")], actions)
  }
}

fn view_summary_chip(chip: SummaryChip) -> Element(msg) {
  case chip {
    SummaryChip(label:, value:, tone:) ->
      signal_chip.metric(label, value, tone)
      |> signal_chip.with_class("work-surface-chip")
      |> signal_chip.with_parts(
        "work-surface-chip-value",
        "work-surface-chip-label",
      )
      |> signal_chip.with_testid("work-surface-chip")
      |> signal_chip.view

    TaskSummaryChip(locale:, metric:) ->
      task_metric_chip.view(task_metric_chip.Config(
        locale: locale,
        metric: metric,
        variant: task_metric_chip.Compact,
        extra_class: Some("work-surface-chip"),
        testid: Some("work-surface-chip"),
      ))
  }
}
