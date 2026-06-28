import gleeunit
import support/render_assertions

import domain/metrics.{
  NoSample, OrgMetricsOverview, OrgMetricsProjectOverview, WindowDays,
}
import domain/remote.{Loaded, NotAsked}
import gleam/option as opt

import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/i18n/locale

pub fn main() {
  gleeunit.main()
}

pub fn overview_no_sample_renders_label_test() {
  let overview =
    OrgMetricsOverview(
      window_days: WindowDays(30),
      available_count: 3,
      claimed_count: 2,
      ongoing_count: 1,
      released_count: 1,
      closed_count: 1,
      release_rate_percent: opt.Some(50),
      pool_flow_ratio_percent: opt.Some(80),
      time_to_first_claim: NoSample,
      time_to_first_claim_buckets: [],
      release_rate_buckets: [],
      wip_count: 2,
      avg_claim_to_complete_ms: opt.None,
      avg_time_in_claimed_ms: opt.None,
      stale_claims_count: 0,
      by_project: [
        OrgMetricsProjectOverview(
          project_id: 7,
          project_name: "Core",
          available_count: 1,
          claimed_count: 2,
          ongoing_count: 1,
          released_count: 1,
          closed_count: 1,
          release_rate_percent: opt.Some(50),
          pool_flow_ratio_percent: opt.Some(80),
          wip_count: 2,
          avg_claim_to_complete_ms: opt.None,
          avg_time_in_claimed_ms: opt.None,
          stale_claims_count: 0,
        ),
      ],
    )

  let config =
    metrics_view.Config(
      locale: locale.En,
      overview: Loaded(overview),
      project_tasks: NotAsked,
      selected_project: opt.None,
      on_project_selected: fn(project_id) { project_id },
    )

  let html = metrics_view.view_metrics(config) |> render_assertions.html

  render_assertions.contains(html, "Flow health")
  render_assertions.contains(html, "No sample (n=0)")
  render_assertions.contains(html, "Time to first claim")
  render_assertions.contains(html, "Core")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-xs")
  render_assertions.not_contains(html, "class=\"btn-xs\"")
}
