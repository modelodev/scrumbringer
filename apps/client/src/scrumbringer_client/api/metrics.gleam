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
import domain/task_status.{
  type OngoingBy, type TaskStatus, type WorkState, Available, OngoingBy,
  WorkAvailable, WorkClaimed, WorkCompleted, WorkOngoing, parse_task_status,
}
import domain/task.{Task}
import domain/task_type.{type TaskTypeInline, TaskTypeInline}
import domain/metrics.{
  type MetricsProjectTask, type MyMetrics, type OrgMetricsBucket,
  type OrgMetricsOverview, type OrgMetricsProjectOverview,
  type OrgMetricsProjectTasksPayload, MetricsProjectTask, MyMetrics,
  OrgMetricsBucket, OrgMetricsOverview, OrgMetricsProjectOverview,
  OrgMetricsProjectTasksPayload,
}

// =============================================================================
// Decoders
// =============================================================================

fn my_metrics_decoder() -> decode.Decoder(MyMetrics) {
  use window_days <- decode.field("window_days", decode.int)
  use claimed_count <- decode.field("claimed_count", decode.int)
  use released_count <- decode.field("released_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)

  decode.success(MyMetrics(
    window_days: window_days,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
  ))
}

fn org_metrics_bucket_decoder() -> decode.Decoder(OrgMetricsBucket) {
  use bucket <- decode.field("bucket", decode.string)
  use count <- decode.field("count", decode.int)
  decode.success(OrgMetricsBucket(bucket: bucket, count: count))
}

fn org_metrics_project_overview_decoder() -> decode.Decoder(
  OrgMetricsProjectOverview,
) {
  use project_id <- decode.field("project_id", decode.int)
  use project_name <- decode.field("project_name", decode.string)
  use claimed_count <- decode.field("claimed_count", decode.int)
  use released_count <- decode.field("released_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use release_rate_percent <- decode.optional_field(
    "release_rate_percent",
    option.None,
    decode.optional(decode.int),
  )
  use pool_flow_ratio_percent <- decode.optional_field(
    "pool_flow_ratio_percent",
    option.None,
    decode.optional(decode.int),
  )

  decode.success(OrgMetricsProjectOverview(
    project_id: project_id,
    project_name: project_name,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
  ))
}

fn org_metrics_overview_decoder() -> decode.Decoder(OrgMetricsOverview) {
  let totals_decoder = {
    use claimed_count <- decode.field("claimed_count", decode.int)
    use released_count <- decode.field("released_count", decode.int)
    use completed_count <- decode.field("completed_count", decode.int)
    decode.success(#(claimed_count, released_count, completed_count))
  }

  use window_days <- decode.field("window_days", decode.int)
  use totals <- decode.field("totals", totals_decoder)
  use release_rate_percent <- decode.optional_field(
    "release_rate_percent",
    option.None,
    decode.optional(decode.int),
  )
  use pool_flow_ratio_percent <- decode.optional_field(
    "pool_flow_ratio_percent",
    option.None,
    decode.optional(decode.int),
  )
  use time_to_first_claim_p50_ms <- decode.optional_field(
    "time_to_first_claim_p50_ms",
    option.None,
    decode.optional(decode.int),
  )
  use time_to_first_claim_sample_size <- decode.field(
    "time_to_first_claim_sample_size",
    decode.int,
  )
  use time_to_first_claim_buckets <- decode.field(
    "time_to_first_claim_buckets",
    decode.list(org_metrics_bucket_decoder()),
  )
  use release_rate_buckets <- decode.field(
    "release_rate_buckets",
    decode.list(org_metrics_bucket_decoder()),
  )
  use by_project <- decode.field(
    "by_project",
    decode.list(org_metrics_project_overview_decoder()),
  )

  let #(claimed_count, released_count, completed_count) = totals

  decode.success(OrgMetricsOverview(
    window_days: window_days,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
    time_to_first_claim_p50_ms: time_to_first_claim_p50_ms,
    time_to_first_claim_sample_size: time_to_first_claim_sample_size,
    time_to_first_claim_buckets: time_to_first_claim_buckets,
    release_rate_buckets: release_rate_buckets,
    by_project: by_project,
  ))
}

fn task_type_inline_decoder() -> decode.Decoder(TaskTypeInline) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  decode.success(TaskTypeInline(id: id, name: name, icon: icon))
}

fn ongoing_by_decoder() -> decode.Decoder(OngoingBy) {
  use user_id <- decode.field("user_id", decode.int)
  decode.success(OngoingBy(user_id: user_id))
}

fn work_state_decoder() -> decode.Decoder(WorkState) {
  decode.string
  |> decode.map(fn(raw) {
    case raw {
      "available" -> WorkAvailable
      "claimed" -> WorkClaimed
      "ongoing" -> WorkOngoing
      "completed" -> WorkCompleted
      _ -> WorkClaimed
    }
  })
}

fn metrics_project_task_decoder() -> decode.Decoder(MetricsProjectTask) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use type_id <- decode.field("type_id", decode.int)
  use title <- decode.field("title", decode.string)

  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )

  use priority <- decode.field("priority", decode.int)
  use status_raw <- decode.field("status", decode.string)

  let status: TaskStatus = case parse_task_status(status_raw) {
    Ok(s) -> s
    Error(_) -> Available
  }

  use created_by <- decode.field("created_by", decode.int)

  use claimed_by <- decode.optional_field(
    "claimed_by",
    option.None,
    decode.optional(decode.int),
  )

  use claimed_at <- decode.optional_field(
    "claimed_at",
    option.None,
    decode.optional(decode.string),
  )

  use completed_at <- decode.optional_field(
    "completed_at",
    option.None,
    decode.optional(decode.string),
  )

  use created_at <- decode.field("created_at", decode.string)
  use version <- decode.field("version", decode.int)

  use claim_count <- decode.field("claim_count", decode.int)
  use release_count <- decode.field("release_count", decode.int)
  use complete_count <- decode.field("complete_count", decode.int)
  use first_claim_at <- decode.optional_field(
    "first_claim_at",
    option.None,
    decode.optional(decode.string),
  )

  use task_type <- decode.field("task_type", task_type_inline_decoder())
  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(ongoing_by_decoder()),
  )
  use work_state <- decode.field("work_state", work_state_decoder())

  let task =
    Task(
      id: id,
      project_id: project_id,
      type_id: type_id,
      task_type: task_type,
      ongoing_by: ongoing_by,
      title: title,
      description: description,
      priority: priority,
      status: status,
      work_state: work_state,
      created_by: created_by,
      claimed_by: claimed_by,
      claimed_at: claimed_at,
      completed_at: completed_at,
      created_at: created_at,
      version: version,
    )

  decode.success(MetricsProjectTask(
    task: task,
    claim_count: claim_count,
    release_count: release_count,
    complete_count: complete_count,
    first_claim_at: first_claim_at,
  ))
}

fn org_metrics_project_tasks_payload_decoder() -> decode.Decoder(
  OrgMetricsProjectTasksPayload,
) {
  use window_days <- decode.field("window_days", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use tasks <- decode.field(
    "tasks",
    decode.list(metrics_project_task_decoder()),
  )

  decode.success(OrgMetricsProjectTasksPayload(
    window_days: window_days,
    project_id: project_id,
    tasks: tasks,
  ))
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
