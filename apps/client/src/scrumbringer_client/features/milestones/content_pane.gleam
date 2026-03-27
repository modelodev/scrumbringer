import domain/milestone.{type MilestoneProgress, type MilestoneState}
import gleam/int
import gleam/option
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, h3, p, span, text}
import lustre/event

import scrumbringer_client/client_state
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/detail_metrics

pub type Config(msg) {
  Config(
    model: client_state.Model,
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
      view_header_actions(config),
    ]),
    case progress.milestone.description {
      option.Some(description) if description != "" ->
        p([attribute.class("milestone-item-description")], [text(description)])
      _ -> none()
    },
    div([attribute.class("milestone-item-stats")], [
      stat_pill(
        config.model,
        i18n_text.MilestoneCardsCount(progress.cards_total),
      ),
      stat_pill(
        config.model,
        i18n_text.MilestoneTasksInCardsCount(config.tasks_in_cards),
      ),
      stat_pill(
        config.model,
        i18n_text.MilestoneLooseTasksCount(config.loose_tasks),
      ),
    ]),
    card_progress.view(
      progress.cards_completed + progress.tasks_completed,
      progress.cards_total + progress.tasks_total,
      card_progress.Compact,
    ),
  ])
}

fn stat_pill(model: client_state.Model, label: i18n_text.Text) -> Element(msg) {
  span([attribute.class("milestone-stat-pill")], [
    text(helpers_i18n.i18n_t(model, label)),
  ])
}

fn view_header_actions(config: Config(msg)) -> Element(msg) {
  div([attribute.class("milestone-detail-actions")], config.actions)
}

fn view_summary_block(config: Config(msg)) -> Element(msg) {
  let summary_meta =
    helpers_i18n.i18n_t(
      config.model,
      i18n_text.MilestoneLooseTasksCount(config.loose_tasks),
    )
    <> " · "
    <> helpers_i18n.i18n_t(
      config.model,
      i18n_text.MilestoneBlockedTasksCount(config.blocked_tasks),
    )

  div([attribute.class("milestone-subsection milestone-inline-section")], [
    button(
      [
        attribute.class("milestone-summary-toggle"),
        attribute.type_("button"),
        attribute.attribute("aria-expanded", case config.summary_expanded {
          True -> "true"
          False -> "false"
        }),
        event.on_click(config.on_summary_toggle),
      ],
      [
        span([attribute.class("milestone-subsection-title")], [
          text(helpers_i18n.i18n_t(
            config.model,
            i18n_text.MilestoneStructureSummary,
          )),
        ]),
        span([attribute.class("milestone-summary-meta")], [text(summary_meta)]),
      ],
    ),
    case config.summary_expanded {
      True ->
        div([attribute.class("milestone-summary-grid")], [
          div([attribute.class("milestone-summary-column")], [
            p([attribute.class("milestone-summary-heading")], [
              text(helpers_i18n.i18n_t(
                config.model,
                i18n_text.MilestoneHealthSummary,
              )),
            ]),
            div(
              [
                attribute.class(
                  "milestone-planning-summary milestone-summary-list",
                ),
              ],
              [
                detail_metrics.view_row(
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneLifecycle,
                  ),
                  config.milestone_state_label(config.progress.milestone.state),
                ),
                detail_metrics.view_row(
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneCardsLabel,
                  ),
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneCardsCount(config.progress.cards_total),
                  ),
                ),
                detail_metrics.view_row(
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneTasksLabel,
                  ),
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneTasksInCardsCount(config.tasks_in_cards),
                  ),
                ),
                detail_metrics.view_row(
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneLooseTasksNotice,
                  ),
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneLooseTasksCount(config.loose_tasks),
                  ),
                ),
                detail_metrics.view_row(
                  helpers_i18n.i18n_t(config.model, i18n_text.Blocked),
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneBlockedTasksCount(config.blocked_tasks),
                  ),
                ),
                detail_metrics.view_row(
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneEmptyCardsLabel,
                  ),
                  helpers_i18n.i18n_t(
                    config.model,
                    i18n_text.MilestoneEmptyCardsCount(config.empty_cards),
                  ),
                ),
              ],
            ),
          ]),
          div([attribute.class("milestone-summary-column")], [
            p([attribute.class("milestone-summary-heading")], [
              text(helpers_i18n.i18n_t(
                config.model,
                i18n_text.MilestoneMetricsSummary,
              )),
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
