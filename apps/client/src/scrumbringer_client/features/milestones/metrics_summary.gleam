//// Milestone metrics summary view.

import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, p, text}

import domain/metrics.{type MilestoneModalMetrics}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/detail_metrics

/// Data needed to render milestone metrics summary.
pub type Config {
  Config(locale: Locale, metrics: Remote(MilestoneModalMetrics))
}

/// Render compact milestone metrics for the milestone detail summary.
pub fn view(config: Config) -> Element(msg) {
  case config.metrics {
    NotAsked | Loading ->
      p([attribute.class("milestone-metrics-loading")], [
        text(i18n.t(config.locale, i18n_text.LoadingMetrics)),
      ])

    Failed(_) ->
      p([attribute.class("milestone-metrics-error")], [
        text(i18n.t(config.locale, i18n_text.MetricsLoadError)),
      ])

    Loaded(metrics) ->
      div([attribute.class("milestone-planning-summary")], [
        detail_metrics.view_row(
          i18n.t(config.locale, i18n_text.MilestoneCardsLabel),
          int.to_string(metrics.cards_completed)
            <> "/"
            <> int.to_string(metrics.cards_total),
        ),
        detail_metrics.view_row(
          i18n.t(config.locale, i18n_text.MilestoneTasksLabel),
          int.to_string(metrics.tasks_completed)
            <> "/"
            <> int.to_string(metrics.tasks_total),
        ),
        detail_metrics.view_row(
          i18n.t(config.locale, i18n_text.MetricsPoolLifetimeAvg),
          detail_metrics.format_duration_s(metrics.health.avg_pool_lifetime_s),
        ),
        detail_metrics.view_row(
          i18n.t(config.locale, i18n_text.MetricsRebotesAvg),
          int.to_string(metrics.health.avg_rebotes),
        ),
      ])
  }
}
