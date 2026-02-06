//// Metrics API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides metrics API operations including personal metrics,
//// organization-wide metrics overview, and project-level task metrics.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/metrics
////
//// metrics.get_me_metrics(30, MyMetricsFetched)
//// metrics.get_org_metrics_overview(30, OrgMetricsFetched)
//// metrics.get_org_metrics_project_tasks(project_id, 30, TaskMetricsFetched)
//// ```

import gleam/dynamic/decode
import gleam/int
import gleam/option

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}

// Import types from shared domain
import domain/metrics.{
  type MyMetrics, type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  type OrgMetricsUserOverview,
}
import domain/metrics/codec as metrics_codec

// =============================================================================
// Decoders
// =============================================================================

fn my_metrics_decoder() -> decode.Decoder(MyMetrics) {
  metrics_codec.my_metrics_decoder()
}

fn org_metrics_overview_decoder() -> decode.Decoder(OrgMetricsOverview) {
  metrics_codec.org_metrics_overview_decoder()
}

fn org_metrics_user_overview_decoder() -> decode.Decoder(OrgMetricsUserOverview) {
  metrics_codec.org_metrics_user_overview_decoder()
}

fn org_metrics_project_tasks_payload_decoder() -> decode.Decoder(
  OrgMetricsProjectTasksPayload,
) {
  metrics_codec.org_metrics_project_tasks_payload_decoder()
}

// =============================================================================
// API Functions
// =============================================================================

/// Get current user's personal metrics.
pub fn get_me_metrics(
  window_days: Int,
  to_msg: fn(ApiResult(MyMetrics)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("metrics", my_metrics_decoder(), decode.success)
  core.request(
    "GET",
    "/api/v1/me/metrics?window_days=" <> int.to_string(window_days),
    option.None,
    decoder,
    to_msg,
  )
}

/// Get organization-wide metrics overview.
pub fn get_org_metrics_overview(
  window_days: Int,
  to_msg: fn(ApiResult(OrgMetricsOverview)) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("overview", org_metrics_overview_decoder(), decode.success)

  core.request(
    "GET",
    "/api/v1/org/metrics/overview?window_days=" <> int.to_string(window_days),
    option.None,
    decoder,
    to_msg,
  )
}

/// Get metrics for tasks in a specific project.
pub fn get_org_metrics_project_tasks(
  project_id: Int,
  window_days: Int,
  to_msg: fn(ApiResult(OrgMetricsProjectTasksPayload)) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/org/metrics/projects/"
      <> int.to_string(project_id)
      <> "/tasks?window_days="
      <> int.to_string(window_days),
    option.None,
    org_metrics_project_tasks_payload_decoder(),
    to_msg,
  )
}

/// Get org metrics per user (admin-only).
pub fn get_org_metrics_users(
  window_days: Int,
  to_msg: fn(ApiResult(List(OrgMetricsUserOverview))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "users",
      decode.list(org_metrics_user_overview_decoder()),
      decode.success,
    )
  core.request(
    "GET",
    "/api/v1/org/metrics/users?window_days=" <> int.to_string(window_days),
    option.None,
    decoder,
    to_msg,
  )
}
