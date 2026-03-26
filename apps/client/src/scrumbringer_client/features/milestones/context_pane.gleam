import domain/milestone.{type MilestoneProgress}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, p, text}

import scrumbringer_client/client_state
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/detail_metrics

pub type Config(msg) {
  Config(
    model: client_state.Model,
    progress: MilestoneProgress,
    tasks_in_cards: Int,
    loose_tasks: Int,
    blocked_tasks: Int,
    empty_cards: Int,
    actions: Element(msg),
    milestone_state_label: String,
    metrics_summary: Element(msg),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("milestone-context-pane")], [
    section(config.model, i18n_text.MilestoneActions, config.actions),
    section(
      config.model,
      i18n_text.MilestoneHealthSummary,
      div([attribute.class("milestone-planning-summary")], [
        detail_metrics.view_row(
          helpers_i18n.i18n_t(config.model, i18n_text.MilestoneLifecycle),
          config.milestone_state_label,
        ),
        detail_metrics.view_row(
          helpers_i18n.i18n_t(config.model, i18n_text.MilestoneCardsLabel),
          helpers_i18n.i18n_t(
            config.model,
            i18n_text.MilestoneCardsCount(config.progress.cards_total),
          ),
        ),
        detail_metrics.view_row(
          helpers_i18n.i18n_t(config.model, i18n_text.MilestoneTasksLabel),
          helpers_i18n.i18n_t(
            config.model,
            i18n_text.MilestoneTasksInCardsCount(config.tasks_in_cards),
          ),
        ),
        detail_metrics.view_row(
          helpers_i18n.i18n_t(config.model, i18n_text.MilestoneLooseTasksNotice),
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
          helpers_i18n.i18n_t(config.model, i18n_text.MilestoneEmptyCardsLabel),
          helpers_i18n.i18n_t(
            config.model,
            i18n_text.MilestoneEmptyCardsCount(config.empty_cards),
          ),
        ),
      ]),
    ),
    section(
      config.model,
      i18n_text.MilestoneMetricsSummary,
      config.metrics_summary,
    ),
  ])
}

fn section(
  model: client_state.Model,
  title: i18n_text.Text,
  content: Element(msg),
) -> Element(msg) {
  div([attribute.class("milestone-subsection milestone-context-section")], [
    p(
      [
        attribute.class(
          "milestone-subsection-title milestone-context-section-title",
        ),
      ],
      [
        text(helpers_i18n.i18n_t(model, title)),
      ],
    ),
    content,
  ])
}
