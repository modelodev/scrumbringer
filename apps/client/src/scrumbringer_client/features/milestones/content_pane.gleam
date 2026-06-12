import domain/milestone.{type MilestoneProgress, type MilestoneState}
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, h3, p, span, text}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/tone

pub type Config(msg) {
  Config(
    locale: Locale,
    progress: MilestoneProgress,
    loose_tasks: Int,
    blocked_tasks: Int,
    empty_cards: Int,
    cards_without_progress: Int,
    cards_section: Element(msg),
    loose_tasks_panel: Element(msg),
    actions: List(Element(msg)),
    summary_expanded: Bool,
    on_summary_toggle: msg,
    milestone_state_label: fn(MilestoneState) -> String,
    milestone_state_variant: fn(MilestoneState) -> badge.BadgeVariant,
    progress_percentage: fn(MilestoneProgress) -> Int,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("milestone-detail-main")], [
    view_header(config),
    view_summary_block(config),
    div([attribute.class("milestone-detail-content")], [
      config.cards_section,
      config.loose_tasks_panel,
    ]),
  ])
}

fn view_header(config: Config(msg)) -> Element(msg) {
  let progress = config.progress

  div([attribute.class("milestone-detail-header")], [
    div([attribute.class("milestone-detail-header-main")], [
      div([attribute.class("milestone-detail-heading")], [
        h3([attribute.class("milestone-detail-title")], [
          text(progress.milestone.name),
        ]),
        div([attribute.class("milestone-item-meta detail-meta")], [
          badge.quick(
            config.milestone_state_label(progress.milestone.state),
            config.milestone_state_variant(progress.milestone.state),
          ),
          span([attribute.class("milestone-progress-percent")], [
            text(int.to_string(config.progress_percentage(progress)) <> "%"),
          ]),
        ]),
      ]),
    ]),
    case progress.milestone.description {
      option.Some(description) if description != "" ->
        p([attribute.class("milestone-item-description")], [text(description)])
      _ -> none()
    },
    view_structural_summary_strip(config),
    card_progress.view(
      progress.cards_completed + progress.tasks_completed,
      progress.cards_total + progress.tasks_total,
      card_progress.Compact,
    ),
    view_header_actions(config),
  ])
}

fn view_structural_summary_strip(config: Config(msg)) -> Element(msg) {
  let progress = config.progress

  div(
    [
      attribute.class("milestone-structure-strip"),
      attribute.attribute("data-testid", "milestone-structure-strip"),
    ],
    list.append(
      [
        structure_chip(
          i18n.t(
            config.locale,
            i18n_text.MilestoneCardsProgress(
              progress.cards_completed,
              progress.cards_total,
            ),
          ),
          tone.Primary,
          "progress",
        ),
        structure_chip(
          i18n.t(
            config.locale,
            i18n_text.MilestoneCardsCount(progress.cards_total),
          ),
          tone.Neutral,
          "cards",
        ),
      ],
      summary_signal_chips(config),
    ),
  )
}

fn summary_signal_chips(config: Config(msg)) -> List(Element(msg)) {
  [
    signal_summary(
      config.loose_tasks,
      i18n_text.MilestoneLooseTasksCount(config.loose_tasks),
      tone.Warning,
      "loose",
    ),
    signal_summary(
      config.blocked_tasks,
      i18n_text.MilestoneBlockedTasksCount(config.blocked_tasks),
      tone.Blocked,
      "blocked",
    ),
    signal_summary(
      config.empty_cards,
      i18n_text.MilestoneEmptyCardsCount(config.empty_cards),
      tone.Warning,
      "empty",
    ),
    signal_summary(
      config.cards_without_progress,
      i18n_text.MilestoneCardsWithoutProgressCount(
        config.cards_without_progress,
      ),
      tone.Warning,
      "no-progress",
    ),
  ]
  |> list.filter_map(fn(item) {
    let #(count, label, tone_value, extra_class) = item
    case count > 0 {
      True ->
        Ok(structure_chip(i18n.t(config.locale, label), tone_value, extra_class))
      False -> Error(Nil)
    }
  })
}

fn signal_summary(
  count: Int,
  label: i18n_text.Text,
  tone_value: tone.Tone,
  extra_class: String,
) -> #(Int, i18n_text.Text, tone.Tone, String) {
  #(count, label, tone_value, extra_class)
}

fn structure_chip(
  label: String,
  tone_value: tone.Tone,
  extra_class: String,
) -> Element(msg) {
  signal_chip.text(label, tone_value)
  |> signal_chip.with_class("milestone-structure-chip")
  |> signal_chip.with_extra_class(extra_class)
  |> signal_chip.with_testid("milestone-structure-chip")
  |> signal_chip.view
}

fn view_header_actions(config: Config(msg)) -> Element(msg) {
  case config.actions {
    [] -> none()
    _ -> div([attribute.class("milestone-detail-actions")], config.actions)
  }
}

fn view_summary_block(config: Config(msg)) -> Element(msg) {
  let summary_meta = diagnostic_summary(config)

  div([attribute.class("milestone-subsection milestone-inline-section")], [
    button(
      [
        attribute.class("milestone-summary-toggle"),
        attribute.type_("button"),
        attribute.attribute(
          "aria-expanded",
          attribute_value.boolean(config.summary_expanded),
        ),
        event.on_click(config.on_summary_toggle),
      ],
      [
        span([attribute.class("milestone-subsection-title")], [
          text(i18n.t(config.locale, i18n_text.MilestoneStructureSummary)),
        ]),
        span([attribute.class("milestone-summary-meta")], [text(summary_meta)]),
      ],
    ),
    case config.summary_expanded {
      True ->
        div(
          [attribute.class("milestone-diagnostic-list")],
          diagnostic_items(config),
        )
      False -> none()
    },
  ])
}

fn diagnostic_summary(config: Config(msg)) -> String {
  case diagnostic_texts(config) {
    [] -> i18n.t(config.locale, i18n_text.MilestoneStructureComplete)
    [first, ..] -> first
  }
}

fn diagnostic_items(config: Config(msg)) -> List(Element(msg)) {
  case diagnostic_texts(config) {
    [] -> [
      p([attribute.class("milestone-diagnostic-item is-complete")], [
        text(i18n.t(config.locale, i18n_text.MilestoneStructureComplete)),
      ]),
    ]
    items ->
      list.map(items, fn(item) {
        p([attribute.class("milestone-diagnostic-item")], [text(item)])
      })
  }
}

fn diagnostic_texts(config: Config(msg)) -> List(String) {
  [
    diagnostic_if(
      config.loose_tasks,
      i18n_text.MilestoneLooseTasksDiagnostic(config.loose_tasks),
    ),
    diagnostic_if(
      config.blocked_tasks,
      i18n_text.MilestoneBlockedTasksDiagnostic(config.blocked_tasks),
    ),
    diagnostic_if(
      config.empty_cards,
      i18n_text.MilestoneEmptyCardsDiagnostic(config.empty_cards),
    ),
    diagnostic_if(
      config.cards_without_progress,
      i18n_text.MilestoneCardsWithoutProgressDiagnostic(
        config.cards_without_progress,
      ),
    ),
  ]
  |> list.filter_map(fn(item) {
    let #(count, label) = item
    case count > 0 {
      True -> Ok(i18n.t(config.locale, label))
      False -> Error(Nil)
    }
  })
}

fn diagnostic_if(count: Int, label: i18n_text.Text) -> #(Int, i18n_text.Text) {
  #(count, label)
}
