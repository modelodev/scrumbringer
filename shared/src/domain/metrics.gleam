//// Metrics domain types for ScrumBringer.
////
//// Defines structures for personal, organization, and project metrics.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/metrics.{type MyMetrics, type OrgMetricsOverview}
////
//// let metrics = MyMetrics(window_days: 30, claimed_count: 10, released_count: 2, completed_count: 8)
//// ```

import domain/task.{type Task}
import gleam/option.{type Option}

// =============================================================================
// Types
// =============================================================================

/// Personal metrics for the current user.
///
/// ## Example
///
/// ```gleam
/// MyMetrics(window_days: 30, claimed_count: 15, released_count: 3, completed_count: 12)
/// ```
pub type MyMetrics {
  MyMetrics(
    window_days: Int,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
  )
}

/// A bucket in a histogram.
///
/// ## Example
///
/// ```gleam
/// OrgMetricsBucket(bucket: "0-1h", count: 15)
/// ```
pub type OrgMetricsBucket {
  OrgMetricsBucket(bucket: String, count: Int)
}

/// Per-project metrics overview.
///
/// ## Example
///
/// ```gleam
/// OrgMetricsProjectOverview(
///   project_id: 1,
///   project_name: "Sprint 1",
///   claimed_count: 50,
///   released_count: 10,
///   completed_count: 40,
///   release_rate_percent: Some(20),
///   pool_flow_ratio_percent: Some(80),
/// )
/// ```
pub type OrgMetricsProjectOverview {
  OrgMetricsProjectOverview(
    project_id: Int,
    project_name: String,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
    release_rate_percent: Option(Int),
    pool_flow_ratio_percent: Option(Int),
  )
}

/// Organization-wide metrics overview.
///
/// ## Example
///
/// ```gleam
/// OrgMetricsOverview(
///   window_days: 30,
///   claimed_count: 100,
///   released_count: 20,
///   completed_count: 80,
///   release_rate_percent: Some(20),
///   pool_flow_ratio_percent: Some(80),
///   time_to_first_claim_p50_ms: Some(3600000),
///   time_to_first_claim_sample_size: 50,
///   time_to_first_claim_buckets: [],
///   release_rate_buckets: [],
///   by_project: [],
/// )
/// ```
pub type OrgMetricsOverview {
  OrgMetricsOverview(
    window_days: Int,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
    release_rate_percent: Option(Int),
    pool_flow_ratio_percent: Option(Int),
    time_to_first_claim_p50_ms: Option(Int),
    time_to_first_claim_sample_size: Int,
    time_to_first_claim_buckets: List(OrgMetricsBucket),
    release_rate_buckets: List(OrgMetricsBucket),
    by_project: List(OrgMetricsProjectOverview),
  )
}

/// A task with its metrics for project task detail view.
///
/// ## Example
///
/// ```gleam
/// MetricsProjectTask(
///   task: task,
///   claim_count: 3,
///   release_count: 1,
///   complete_count: 1,
///   first_claim_at: Some("2024-01-17T12:00:00Z"),
/// )
/// ```
pub type MetricsProjectTask {
  MetricsProjectTask(
    task: Task,
    claim_count: Int,
    release_count: Int,
    complete_count: Int,
    first_claim_at: Option(String),
  )
}

/// Payload for project tasks metrics.
///
/// ## Example
///
/// ```gleam
/// OrgMetricsProjectTasksPayload(window_days: 30, project_id: 1, tasks: [])
/// ```
pub type OrgMetricsProjectTasksPayload {
  OrgMetricsProjectTasksPayload(
    window_days: Int,
    project_id: Int,
    tasks: List(MetricsProjectTask),
  )
}
