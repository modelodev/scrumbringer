import gleam/string
import gleeunit
import gleeunit/should
import lustre/element

import domain/metrics.{NoSample, OrgMetricsOverview, WindowDays}
import domain/remote.{Loaded}
import gleam/option as opt

import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/features/metrics/view as metrics_view

pub fn main() {
  gleeunit.main()
}

fn base_model() -> client_state.Model {
  client_state.default_model()
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

  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(..admin, admin_metrics_overview: Loaded(overview))
    })

  let html =
    metrics_view.view_metrics(model, opt.None) |> element.to_document_string

  string.contains(html, "Flow health") |> should.be_true
  string.contains(html, "No sample (n=0)") |> should.be_true
  string.contains(html, "Time to first claim") |> should.be_true
}
