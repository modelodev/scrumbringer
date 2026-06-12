//// Shared composition for member work surfaces.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, p, text}

import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/tone

pub type SummaryChip {
  SummaryChip(label: String, value: String, tone: tone.Tone)
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

pub fn summary_chip(
  label: String,
  value: String,
  tone_value: tone.Tone,
) -> SummaryChip {
  SummaryChip(label: label, value: value, tone: tone_value)
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
  signal_chip.metric(chip.label, chip.value, chip.tone)
  |> signal_chip.with_class("work-surface-chip")
  |> signal_chip.with_parts(
    "work-surface-chip-value",
    "work-surface-chip-label",
  )
  |> signal_chip.with_testid("work-surface-chip")
  |> signal_chip.view
}
