//// Card Show summary section.
////
//// Keeps the summary tab rendering separate from Card Show state/update logic.

import gleam/int
import gleam/option

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import domain/card.{type Card}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/pinned_context
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip

pub type Config(msg) {
  Config(
    locale: Locale,
    card: Card,
    blocked_count: Int,
    path: Element(msg),
    pinned_notes: List(pinned_context.PinnedNote),
    on_open_notes: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-summary-section detail-section")], [
    signal(config),
    metrics(config),
    case config.card.description {
      "" ->
        description(
          config,
          t(config.locale, i18n_text.CardSummaryNoDescription),
          True,
        )
      value -> description(config, value, False)
    },
    div([attribute.class("card-summary-block card-summary-structure")], [
      span([attribute.class("detail-section-kicker")], [
        text(t(config.locale, i18n_text.PlanModeStructure)),
      ]),
      element_item(t(config.locale, i18n_text.HierarchyScopeCardTitle), [
        config.path,
      ]),
      item(t(config.locale, i18n_text.CardTasks), work_progress_copy(config)),
    ]),
    pinned_context.view(pinned_context.Config(
      title: t(config.locale, i18n_text.PinnedContext),
      notes: config.pinned_notes,
      open_notes_label: t(config.locale, i18n_text.OpenNotes),
      more_label: fn(count) {
        t(config.locale, i18n_text.MorePinnedNotes(count))
      },
      on_open_notes: config.on_open_notes,
    )),
  ])
}

fn signal(config: Config(msg)) -> Element(msg) {
  let #(title, body, icon, tone_class) = case
    config.card.task_count,
    config.blocked_count
  {
    0, _ -> #(
      t(config.locale, i18n_text.CardSummaryNoWorkTitle),
      t(config.locale, i18n_text.CardSummaryNoWorkBody),
      icons.EmptyMailbox,
      "is-empty",
    )
    _, blocked if blocked > 0 -> #(
      t(config.locale, i18n_text.CardSummaryBlockedTitle(blocked)),
      t(config.locale, i18n_text.CardSummaryBlockedBody),
      icons.Warning,
      "is-blocked",
    )
    total, _ if config.card.closed_count == total -> #(
      t(config.locale, i18n_text.CardSummaryCompleteTitle),
      t(config.locale, i18n_text.CardSummaryCompleteBody),
      icons.CheckCircle,
      "is-complete",
    )
    _, _ -> #(
      t(config.locale, i18n_text.CardSummaryFlowTitle),
      t(config.locale, i18n_text.CardSummaryFlowBody),
      icons.ChartUp,
      "is-flowing",
    )
  }

  div([attribute.class("card-summary-signal " <> tone_class)], [
    span([attribute.class("card-summary-signal-icon")], [
      icons.nav_icon(icon, icons.Small),
    ]),
    div([attribute.class("card-summary-signal-copy")], [
      span([attribute.class("card-summary-signal-title")], [text(title)]),
      span([attribute.class("card-summary-signal-body")], [text(body)]),
    ]),
  ])
}

fn metrics(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-summary-metrics")], [
    metric(config, task_metric.Total, config.card.task_count, "total"),
    metric(config, task_metric.Closed, config.card.closed_count, "closed"),
    metric(config, task_metric.Blocked, config.blocked_count, "blocked"),
  ])
}

fn metric(
  config: Config(msg),
  kind: task_metric.TaskMetricKind,
  value: Int,
  key: String,
) -> Element(msg) {
  task_metric_chip.view(task_metric_chip.Config(
    locale: config.locale,
    metric: task_metric.metric(kind, value),
    extra_class: option.Some("card-summary-metric"),
    testid: option.Some("card-summary-metric-" <> key),
  ))
}

fn description(
  config: Config(msg),
  description: String,
  muted: Bool,
) -> Element(msg) {
  div([attribute.class("card-summary-block card-summary-description")], [
    span([attribute.class("detail-section-kicker")], [
      text(t(config.locale, i18n_text.Description)),
    ]),
    div(
      [
        attribute.class(case muted {
          True -> "card-summary-description-text muted"
          False -> "card-summary-description-text"
        }),
      ],
      [text(description)],
    ),
  ])
}

fn item(label: String, value: String) -> Element(msg) {
  element_item(label, [text(value)])
}

fn element_item(label: String, value: List(Element(msg))) -> Element(msg) {
  div([attribute.class("detail-summary-item")], [
    span([attribute.class("detail-summary-label")], [text(label)]),
    span([attribute.class("detail-summary-value")], value),
  ])
}

fn work_progress_copy(config: Config(msg)) -> String {
  case config.card.task_count {
    0 -> t(config.locale, i18n_text.CardTasksEmpty)
    total ->
      int.to_string(config.card.closed_count)
      <> " "
      <> t(config.locale, i18n_text.CardTasksClosed)
      <> " - "
      <> int.to_string(total)
      <> " "
      <> t(config.locale, i18n_text.CardTasks)
  }
}

fn t(locale: Locale, key: i18n_text.Text) -> String {
  i18n.t(locale, key)
}
