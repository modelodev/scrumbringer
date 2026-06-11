//// Shared composition for member work surfaces.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, p, span, text}

pub type ChipTone {
  Neutral
  Primary
  Available
  Claimed
  Ongoing
  Blocked
  Warning
  Success
}

pub type SummaryChip {
  SummaryChip(label: String, value: String, tone: ChipTone)
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

pub fn summary_chip(label: String, value: String, tone: ChipTone) -> SummaryChip {
  SummaryChip(label: label, value: value, tone: tone)
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
  span(
    [
      attribute.class("work-surface-chip " <> chip_tone_class(chip.tone)),
      attribute.attribute("data-testid", "work-surface-chip"),
    ],
    [
      span([attribute.class("work-surface-chip-value")], [text(chip.value)]),
      span([attribute.class("work-surface-chip-label")], [text(chip.label)]),
    ],
  )
}

fn chip_tone_class(tone: ChipTone) -> String {
  case tone {
    Neutral -> "neutral"
    Primary -> "primary"
    Available -> "available"
    Claimed -> "claimed"
    Ongoing -> "ongoing"
    Blocked -> "blocked"
    Warning -> "warning"
    Success -> "success"
  }
}
