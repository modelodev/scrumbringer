//// Shared inline task status indicator.

import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import domain/task_status
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_state
import scrumbringer_client/ui/tone

pub type Variant {
  InlineFull
  InlineCompact
}

pub type Config {
  Config(
    locale: Locale,
    status: task_status.TaskPhase,
    variant: Variant,
    label: Option(String),
    title: Option(String),
    extra_class: Option(String),
    testid: Option(String),
  )
}

pub fn view(config: Config) -> Element(msg) {
  let label = case config.label {
    Some(value) -> value
    None -> task_state.label(config.locale, config.status)
  }

  let title = case config.title {
    Some(value) -> value
    None -> task_state.hint(config.locale, config.status)
  }

  span(attrs(config, title), children(config.variant, config.status, label))
}

pub fn full(locale: Locale, status: task_status.TaskPhase) -> Element(msg) {
  view(Config(
    locale: locale,
    status: status,
    variant: InlineFull,
    label: None,
    title: None,
    extra_class: None,
    testid: None,
  ))
}

pub fn compact(locale: Locale, status: task_status.TaskPhase) -> Element(msg) {
  view(Config(
    locale: locale,
    status: status,
    variant: InlineCompact,
    label: None,
    title: None,
    extra_class: None,
    testid: None,
  ))
}

pub fn icon(status: task_status.TaskPhase) -> icons.NavIcon {
  case status {
    task_status.Available -> icons.InboxEmpty
    task_status.Claimed(task_status.Taken) -> icons.ClipboardDoc
    task_status.Claimed(task_status.Ongoing) -> icons.Play
    task_status.Closed -> icons.CheckCircle
  }
}

pub fn tone(status: task_status.TaskPhase) -> tone.Tone {
  case status {
    task_status.Available -> tone.Available
    task_status.Claimed(task_status.Taken) -> tone.Claimed
    task_status.Claimed(task_status.Ongoing) -> tone.Ongoing
    task_status.Closed -> tone.Success
  }
}

fn attrs(config: Config, title: String) -> List(attribute.Attribute(msg)) {
  let class =
    "task-status-indicator "
    <> variant_class(config.variant)
    <> " "
    <> tone.class_name(tone(config.status))

  let class = case config.extra_class {
    Some(extra) -> class <> " " <> extra
    None -> class
  }

  let testid = case config.testid {
    Some(value) -> value
    None -> "task-status-indicator"
  }

  [
    attribute.class(class),
    attribute.attribute("data-testid", testid),
    attribute.attribute("title", title),
    attribute.attribute("aria-label", title),
  ]
}

fn children(
  variant: Variant,
  status: task_status.TaskPhase,
  label: String,
) -> List(Element(msg)) {
  let icon =
    span(
      [
        attribute.class("task-status-indicator-icon"),
        attribute.attribute("aria-hidden", "true"),
      ],
      [icons.nav_icon(icon(status), icons.XSmall)],
    )

  case variant {
    InlineFull -> [
      icon,
      span([attribute.class("task-status-indicator-label")], [text(label)]),
    ]
    InlineCompact -> [icon]
  }
}

fn variant_class(variant: Variant) -> String {
  case variant {
    InlineFull -> "is-full"
    InlineCompact -> "is-compact"
  }
}
