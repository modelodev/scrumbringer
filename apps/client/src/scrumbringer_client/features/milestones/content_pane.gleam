import domain/milestone.{type MilestoneProgress, type MilestoneState}
import gleam/int
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
import scrumbringer_client/ui/detail_metrics

pub type Config(msg) {
  Config(
    locale: Locale,
    progress: MilestoneProgress,
    tasks_in_cards: Int,
    loose_tasks: Int,
    blocked_tasks: Int,
    empty_cards: Int,
    cards_section: Element(msg),
    loose_tasks_panel: Element(msg),
    actions: List(Element(msg)),
    metrics_summary: Element(msg),
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
    [
      summary_chip(
        i18n.t(
          config.locale,
          i18n_text.MilestoneCardsProgress(
            progress.cards_completed,
            progress.cards_total,
          ),
        ),
        "progress",
      ),
      summary_chip(
        i18n.t(
          config.locale,
          i18n_text.MilestoneCardsCount(progress.cards_total),
        ),
        "cards",
      ),
      summary_chip(
        i18n.t(
          config.locale,
          i18n_text.MilestoneTasksInCardsCount(config.tasks_in_cards),
        ),
        "tasks",
      ),
      summary_chip(
        i18n.t(
          config.locale,
          i18n_text.MilestoneLooseTasksCount(config.loose_tasks),
        ),
        "loose",
      ),
      summary_chip(
        i18n.t(
          config.locale,
          i18n_text.MilestoneBlockedTasksCount(config.blocked_tasks),
        ),
        "blocked",
      ),
      summary_chip(
        i18n.t(
          config.locale,
          i18n_text.MilestoneEmptyCardsCount(config.empty_cards),
        ),
        "empty",
      ),
    ],
  )
}

fn summary_chip(label: String, tone: String) -> Element(msg) {
  span(
    [
      attribute.class("milestone-structure-chip " <> tone),
      attribute.attribute("data-testid", "milestone-structure-chip"),
    ],
    [text(label)],
  )
}

fn view_header_actions(config: Config(msg)) -> Element(msg) {
  case config.actions {
    [] -> none()
    _ -> div([attribute.class("milestone-detail-actions")], config.actions)
  }
}

fn view_summary_block(config: Config(msg)) -> Element(msg) {
  let summary_meta =
    i18n.t(
      config.locale,
      i18n_text.MilestoneLooseTasksCount(config.loose_tasks),
    )
    <> " · "
    <> i18n.t(
      config.locale,
      i18n_text.MilestoneBlockedTasksCount(config.blocked_tasks),
    )

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
        div([attribute.class("milestone-summary-grid")], [
          div([attribute.class("milestone-summary-column")], [
            p([attribute.class("milestone-summary-heading")], [
              text(i18n.t(config.locale, i18n_text.MilestoneHealthSummary)),
            ]),
            div(
              [
                attribute.class(
                  "milestone-planning-summary milestone-summary-list",
                ),
              ],
              [
                detail_metrics.view_row(
                  i18n.t(config.locale, i18n_text.MilestoneLifecycle),
                  config.milestone_state_label(config.progress.milestone.state),
                ),
                detail_metrics.view_row(
                  i18n.t(config.locale, i18n_text.MilestoneCardsLabel),
                  i18n.t(
                    config.locale,
                    i18n_text.MilestoneCardsCount(config.progress.cards_total),
                  ),
                ),
                detail_metrics.view_row(
                  i18n.t(config.locale, i18n_text.MilestoneTasksLabel),
                  i18n.t(
                    config.locale,
                    i18n_text.MilestoneTasksInCardsCount(config.tasks_in_cards),
                  ),
                ),
                detail_metrics.view_row(
                  i18n.t(config.locale, i18n_text.MilestoneLooseTasksNotice),
                  i18n.t(
                    config.locale,
                    i18n_text.MilestoneLooseTasksCount(config.loose_tasks),
                  ),
                ),
                detail_metrics.view_row(
                  i18n.t(config.locale, i18n_text.Blocked),
                  i18n.t(
                    config.locale,
                    i18n_text.MilestoneBlockedTasksCount(config.blocked_tasks),
                  ),
                ),
                detail_metrics.view_row(
                  i18n.t(config.locale, i18n_text.MilestoneEmptyCardsLabel),
                  i18n.t(
                    config.locale,
                    i18n_text.MilestoneEmptyCardsCount(config.empty_cards),
                  ),
                ),
              ],
            ),
          ]),
          div([attribute.class("milestone-summary-column")], [
            p([attribute.class("milestone-summary-heading")], [
              text(i18n.t(config.locale, i18n_text.MilestoneMetricsSummary)),
            ]),
            div([attribute.class("milestone-summary-list")], [
              config.metrics_summary,
            ]),
          ]),
        ])
      False -> none()
    },
  ])
}
