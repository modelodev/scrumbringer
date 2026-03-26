import domain/milestone.{type MilestoneProgress, type MilestoneState}
import gleam/int
import gleam/option
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{div, h3, p, span, text}

import scrumbringer_client/client_state
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/card_progress

pub type Config(msg) {
  Config(
    model: client_state.Model,
    progress: MilestoneProgress,
    tasks_in_cards: Int,
    loose_tasks: Int,
    cards_section: Element(msg),
    loose_tasks_panel: Element(msg),
    milestone_state_label: fn(MilestoneState) -> String,
    milestone_state_variant: fn(MilestoneState) -> badge.BadgeVariant,
    progress_percentage: fn(MilestoneProgress) -> Int,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("milestone-detail-main")], [
    view_header(config),
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
