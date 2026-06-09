//// Task detail metrics tab.

import gleam/int
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/metrics.{type TaskModalMetrics}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/detail_metrics

pub type Config {
  Config(locale: Locale, metrics: Remote(TaskModalMetrics))
}

fn t(config: Config, key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config) -> Element(msg) {
  case config.metrics {
    NotAsked | Loading -> empty_state(t(config, i18n_text.LoadingMetrics))

    Failed(_err) -> empty_state(t(config, i18n_text.MetricsLoadError))

    Loaded(metrics) ->
      case is_empty(metrics) {
        True -> empty_state(t(config, i18n_text.MetricsEmptyState))
        False -> metrics_grid(config, metrics)
      }
  }
}

fn empty_state(copy: String) -> Element(msg) {
  div([attribute.class("task-metrics-empty")], [text(copy)])
}

fn metrics_grid(config: Config, metrics: TaskModalMetrics) -> Element(msg) {
  div([attribute.class("task-metrics-grid")], [
    view_detail_row(
      config,
      i18n_text.MetricsClaimCount,
      int.to_string(metrics.claim_count),
    ),
    view_detail_row(
      config,
      i18n_text.MetricsReleaseCount,
      int.to_string(metrics.release_count),
    ),
    view_detail_row(
      config,
      i18n_text.MetricsUniqueExecutors,
      int.to_string(metrics.unique_executors),
    ),
    view_detail_row(
      config,
      i18n_text.MetricsFirstClaimAt,
      metrics.first_claim_at |> first_claim_at_or_not_available(config),
    ),
    view_detail_row(
      config,
      i18n_text.MetricsCurrentStateTime,
      detail_metrics.format_duration_s(metrics.current_state_duration_s),
    ),
    view_detail_row(
      config,
      i18n_text.MetricsPoolLifetime,
      detail_metrics.format_duration_s(metrics.pool_lifetime_s),
    ),
    view_detail_row(
      config,
      i18n_text.MetricsSessionCount,
      int.to_string(metrics.session_count),
    ),
    view_detail_row(
      config,
      i18n_text.MetricsTotalWorkTime,
      detail_metrics.format_duration_s(metrics.total_work_time_s),
    ),
  ])
}

fn is_empty(metrics: TaskModalMetrics) -> Bool {
  metrics.claim_count
  + metrics.release_count
  + metrics.unique_executors
  + metrics.current_state_duration_s
  + metrics.pool_lifetime_s
  + metrics.session_count
  + metrics.total_work_time_s
  == 0
  && metrics.first_claim_at == opt.None
}

fn view_detail_row(
  config: Config,
  label: i18n_text.Text,
  value: String,
) -> Element(msg) {
  detail_metrics.view_row(t(config, label), value)
}

fn first_claim_at_or_not_available(
  value: opt.Option(String),
  config: Config,
) -> String {
  case value {
    opt.None -> t(config, i18n_text.MetricsNotAvailable)
    opt.Some(text) -> text
  }
}
