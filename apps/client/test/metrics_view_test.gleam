import gleam/string
import gleeunit
import lustre/element

import domain/metrics.{NoSample, OrgMetricsOverview, WindowDays}
import domain/remote.{Loaded, NotAsked}
import gleam/option as opt

import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/i18n/locale

pub fn main() {
  gleeunit.main()
}

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

pub fn overview_no_sample_renders_label_test() {
  let overview =
    OrgMetricsOverview(
      window_days: WindowDays(30),
      available_count: 3,
      claimed_count: 2,
      ongoing_count: 1,
      released_count: 1,
      completed_count: 1,
      release_rate_percent: opt.Some(50),
      pool_flow_ratio_percent: opt.Some(80),
      time_to_first_claim: NoSample,
      time_to_first_claim_buckets: [],
      release_rate_buckets: [],
      wip_count: 2,
      avg_claim_to_complete_ms: opt.None,
      avg_time_in_claimed_ms: opt.None,
      stale_claims_count: 0,
      by_project: [],
    )

  let config =
    metrics_view.Config(
      locale: locale.En,
      overview: Loaded(overview),
      project_tasks: NotAsked,
      selected_project: opt.None,
      on_project_selected: fn(project_id) { project_id },
    )

  let html = metrics_view.view_metrics(config) |> element.to_document_string

  assert_contains(html, "Flow health")
  assert_contains(html, "No sample (n=0)")
  assert_contains(html, "Time to first claim")
}
