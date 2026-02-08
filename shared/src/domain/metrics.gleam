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

/// Health status for flow metrics.
pub type Health {
  OkHealth
  Attention
  Alert
}

/// Health-tagged metric value with label.
pub type HealthMetric {
  HealthMetric(value: Int, status: Health, label: String)
}

/// Sampled metric values with explicit no-sample state.
pub type SampledMetric {
  Sampled(value_ms: Int, sample_size: Int)
  NoSample
}

/// Window days with validation.
pub type WindowDays {
  WindowDays(Int)
}

pub type WindowDaysError {
  BelowMin
  AboveMax
}

pub fn window_days_from_int(value: Int) -> Result(WindowDays, WindowDaysError) {
  case value < 1 {
    True -> Error(BelowMin)
    False ->
      case value > 90 {
        True -> Error(AboveMax)
        False -> Ok(WindowDays(value))
      }
  }
}

pub fn window_days_value(window: WindowDays) -> Int {
  let WindowDays(value) = window
  value
}

/// Personal metrics for the current user.
///
/// ## Example
///
/// ```gleam
/// MyMetrics(window_days: 30, claimed_count: 15, released_count: 3, completed_count: 12)
/// ```
pub type MyMetrics {
  MyMetrics(
    window_days: WindowDays,
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
    available_count: Int,
    claimed_count: Int,
    ongoing_count: Int,
    released_count: Int,
    completed_count: Int,
    release_rate_percent: Option(Int),
    pool_flow_ratio_percent: Option(Int),
    wip_count: Int,
    avg_claim_to_complete_ms: Option(Int),
    avg_time_in_claimed_ms: Option(Int),
    stale_claims_count: Int,
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
    window_days: WindowDays,
    available_count: Int,
    claimed_count: Int,
    ongoing_count: Int,
    released_count: Int,
    completed_count: Int,
    release_rate_percent: Option(Int),
    pool_flow_ratio_percent: Option(Int),
    time_to_first_claim: SampledMetric,
    time_to_first_claim_buckets: List(OrgMetricsBucket),
    release_rate_buckets: List(OrgMetricsBucket),
    wip_count: Int,
    avg_claim_to_complete_ms: Option(Int),
    avg_time_in_claimed_ms: Option(Int),
    stale_claims_count: Int,
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
    window_days: WindowDays,
    project_id: Int,
    tasks: List(MetricsProjectTask),
  )
}

/// Per-user metrics overview for admin assignments.
pub type OrgMetricsUserOverview {
  OrgMetricsUserOverview(
    user_id: Int,
    email: String,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
    ongoing_count: Int,
    last_claim_at: Option(String),
  )
}

/// Workflow breakdown item for modal metrics.
pub type WorkflowBreakdown {
  WorkflowBreakdown(name: String, count: Int)
}

/// Shared execution health metrics for card/milestone modal tabs.
pub type ModalExecutionHealth {
  ModalExecutionHealth(
    avg_rebotes: Int,
    avg_pool_lifetime_s: Int,
    avg_executors: Int,
  )
}

/// Milestone metrics payload used in milestone detail modal tab.
pub type MilestoneModalMetrics {
  MilestoneModalMetrics(
    cards_total: Int,
    cards_completed: Int,
    cards_percent: Int,
    tasks_total: Int,
    tasks_completed: Int,
    tasks_percent: Int,
    tasks_available: Int,
    tasks_claimed: Int,
    tasks_ongoing: Int,
    health: ModalExecutionHealth,
    workflows: List(WorkflowBreakdown),
    most_activated: Option(String),
  )
}

/// Card metrics payload used in card detail modal tab.
pub type CardModalMetrics {
  CardModalMetrics(
    tasks_total: Int,
    tasks_completed: Int,
    tasks_percent: Int,
    tasks_available: Int,
    tasks_claimed: Int,
    tasks_ongoing: Int,
    health: ModalExecutionHealth,
    workflows: List(WorkflowBreakdown),
    most_activated: Option(String),
  )
}

/// Task metrics payload used in task detail modal tab.
pub type TaskModalMetrics {
  TaskModalMetrics(
    claim_count: Int,
    release_count: Int,
    unique_executors: Int,
    first_claim_at: Option(String),
    current_state_duration_s: Int,
    pool_lifetime_s: Int,
    session_count: Int,
    total_work_time_s: Int,
  )
}
