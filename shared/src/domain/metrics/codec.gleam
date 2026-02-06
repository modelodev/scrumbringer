//// Metrics JSON decoders.

import gleam/dynamic/decode
import gleam/option

import domain/metrics.{
  type MetricsProjectTask, type MyMetrics, type OrgMetricsBucket,
  type OrgMetricsOverview, type OrgMetricsProjectOverview,
  type OrgMetricsProjectTasksPayload, type OrgMetricsUserOverview,
  type SampledMetric, type WindowDays, MetricsProjectTask, MyMetrics, NoSample,
  OrgMetricsBucket, OrgMetricsOverview, OrgMetricsProjectOverview,
  OrgMetricsProjectTasksPayload, OrgMetricsUserOverview, Sampled, WindowDays,
  window_days_from_int,
}
import domain/task.{Task}
import domain/task/codec as task_codec
import domain/task_state

// =============================================================================
// Decoders
// =============================================================================

/// Decoder for WindowDays.
pub fn window_days_decoder() -> decode.Decoder(WindowDays) {
  use value <- decode.then(decode.int)
  case window_days_from_int(value) {
    Ok(window) -> decode.success(window)
    Error(_) -> decode.failure(WindowDays(30), "WindowDays")
  }
}

/// Decoder for SampledMetric.
pub fn sampled_metric_decoder() -> decode.Decoder(SampledMetric) {
  use p50_ms <- decode.optional_field(
    "p50_ms",
    option.None,
    decode.optional(decode.int),
  )
  use sample_size <- decode.field("sample_size", decode.int)

  case p50_ms, sample_size {
    option.Some(value_ms), size if size > 0 ->
      decode.success(Sampled(value_ms: value_ms, sample_size: size))
    _, _ -> decode.success(NoSample)
  }
}

/// Decoder for MyMetrics.
pub fn my_metrics_decoder() -> decode.Decoder(MyMetrics) {
  use window_days <- decode.field("window_days", window_days_decoder())
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

/// Decoder for OrgMetricsBucket.
pub fn org_metrics_bucket_decoder() -> decode.Decoder(OrgMetricsBucket) {
  use bucket <- decode.field("bucket", decode.string)
  use count <- decode.field("count", decode.int)
  decode.success(OrgMetricsBucket(bucket: bucket, count: count))
}

/// Decoder for OrgMetricsProjectOverview.
pub fn org_metrics_project_overview_decoder() -> decode.Decoder(
  OrgMetricsProjectOverview,
) {
  use project_id <- decode.field("project_id", decode.int)
  use project_name <- decode.field("project_name", decode.string)
  use available_count <- decode.field("available_count", decode.int)
  use claimed_count <- decode.field("claimed_count", decode.int)
  use ongoing_count <- decode.field("ongoing_count", decode.int)
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
  use wip_count <- decode.field("wip_count", decode.int)
  use avg_claim_to_complete_ms <- decode.optional_field(
    "avg_claim_to_complete_ms",
    option.None,
    decode.optional(decode.int),
  )
  use avg_time_in_claimed_ms <- decode.optional_field(
    "avg_time_in_claimed_ms",
    option.None,
    decode.optional(decode.int),
  )
  use stale_claims_count <- decode.field("stale_claims_count", decode.int)

  decode.success(OrgMetricsProjectOverview(
    project_id: project_id,
    project_name: project_name,
    available_count: available_count,
    claimed_count: claimed_count,
    ongoing_count: ongoing_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
    wip_count: wip_count,
    avg_claim_to_complete_ms: avg_claim_to_complete_ms,
    avg_time_in_claimed_ms: avg_time_in_claimed_ms,
    stale_claims_count: stale_claims_count,
  ))
}

/// Decoder for OrgMetricsOverview.
pub fn org_metrics_overview_decoder() -> decode.Decoder(OrgMetricsOverview) {
  let totals_decoder = {
    use available_count <- decode.field("available_count", decode.int)
    use claimed_count <- decode.field("claimed_count", decode.int)
    use ongoing_count <- decode.field("ongoing_count", decode.int)
    use released_count <- decode.field("released_count", decode.int)
    use completed_count <- decode.field("completed_count", decode.int)
    decode.success(#(
      available_count,
      claimed_count,
      ongoing_count,
      released_count,
      completed_count,
    ))
  }

  use window_days <- decode.field("window_days", window_days_decoder())
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
  use time_to_first_claim <- decode.field(
    "time_to_first_claim",
    sampled_metric_decoder(),
  )
  use time_to_first_claim_buckets <- decode.field(
    "time_to_first_claim_buckets",
    decode.list(org_metrics_bucket_decoder()),
  )
  use release_rate_buckets <- decode.field(
    "release_rate_buckets",
    decode.list(org_metrics_bucket_decoder()),
  )
  use wip_count <- decode.field("wip_count", decode.int)
  use avg_claim_to_complete_ms <- decode.optional_field(
    "avg_claim_to_complete_ms",
    option.None,
    decode.optional(decode.int),
  )
  use avg_time_in_claimed_ms <- decode.optional_field(
    "avg_time_in_claimed_ms",
    option.None,
    decode.optional(decode.int),
  )
  use stale_claims_count <- decode.field("stale_claims_count", decode.int)
  use by_project <- decode.field(
    "by_project",
    decode.list(org_metrics_project_overview_decoder()),
  )

  let #(
    available_count,
    claimed_count,
    ongoing_count,
    released_count,
    completed_count,
  ) = totals

  decode.success(OrgMetricsOverview(
    window_days: window_days,
    available_count: available_count,
    claimed_count: claimed_count,
    ongoing_count: ongoing_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
    time_to_first_claim: time_to_first_claim,
    time_to_first_claim_buckets: time_to_first_claim_buckets,
    release_rate_buckets: release_rate_buckets,
    wip_count: wip_count,
    avg_claim_to_complete_ms: avg_claim_to_complete_ms,
    avg_time_in_claimed_ms: avg_time_in_claimed_ms,
    stale_claims_count: stale_claims_count,
    by_project: by_project,
  ))
}

/// Decoder for MetricsProjectTask.
pub fn metrics_project_task_decoder() -> decode.Decoder(MetricsProjectTask) {
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

  use task_type <- decode.field(
    "task_type",
    task_codec.task_type_inline_decoder(),
  )
  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(task_codec.ongoing_by_decoder()),
  )
  let is_ongoing = status_raw == "ongoing"
  let state = case
    task_state.from_db(
      status_raw,
      is_ongoing,
      claimed_by,
      claimed_at,
      completed_at,
    )
  {
    Ok(s) -> s
    Error(_) -> task_state.Available
  }
  let status = task_state.to_status(state)
  let work_state = task_state.to_work_state(state)

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
      state: state,
      status: status,
      work_state: work_state,
      created_by: created_by,
      created_at: created_at,
      version: version,
      // Card fields not available in metrics endpoint
      card_id: option.None,
      card_title: option.None,
      card_color: option.None,
      // Story 5.4: Default to False for metrics
      has_new_notes: False,
      blocked_count: 0,
      dependencies: [],
    )

  decode.success(MetricsProjectTask(
    task: task,
    claim_count: claim_count,
    release_count: release_count,
    complete_count: complete_count,
    first_claim_at: first_claim_at,
  ))
}

/// Decoder for OrgMetricsUserOverview.
pub fn org_metrics_user_overview_decoder() -> decode.Decoder(
  OrgMetricsUserOverview,
) {
  use user_id <- decode.field("user_id", decode.int)
  use email <- decode.field("email", decode.string)
  use claimed_count <- decode.field("claimed_count", decode.int)
  use released_count <- decode.field("released_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use ongoing_count <- decode.field("ongoing_count", decode.int)
  use last_claim_at <- decode.optional_field(
    "last_claim_at",
    option.None,
    decode.optional(decode.string),
  )

  decode.success(OrgMetricsUserOverview(
    user_id: user_id,
    email: email,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    ongoing_count: ongoing_count,
    last_claim_at: last_claim_at,
  ))
}

/// Decoder for OrgMetricsProjectTasksPayload.
pub fn org_metrics_project_tasks_payload_decoder() -> decode.Decoder(
  OrgMetricsProjectTasksPayload,
) {
  use window_days <- decode.field("window_days", window_days_decoder())
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
