//// JSON presenters for metrics endpoints.
////
//// ## Mission
////
//// Converts domain data structures to JSON responses for metrics API.
//// Contains all JSON building logic extracted from org_metrics handlers.
////
//// ## Responsibilities
////
//// - Convert overview data to JSON
//// - Convert project task data to JSON
//// - Provide helper functions for optional values
////
//// ## Non-responsibilities
////
//// - Database queries (see `sql.gleam`)
//// - Business logic/calculations (see `metrics_service.gleam`)
//// - HTTP handling (see `org_metrics.gleam`)

import gleam/json
import gleam/option.{type Option, None, Some}
import helpers/json as json_helpers
import scrumbringer_server/http/metrics_service.{
  type MetricsOverview, type ProjectMetricsRow, type ProjectTask,
  type TimeToFirstClaimBucket, type UserMetricsRow, work_state_to_string,
}

// =============================================================================
// Overview Presenters
// =============================================================================

/// Convert metrics overview to JSON.
pub fn overview_json(overview: MetricsOverview) -> json.Json {
  json.object([
    #(
      "overview",
      json.object([
        #("window_days", json.int(overview.window_days)),
        #(
          "totals",
          json.object([
            #("available_count", json.int(overview.available_count)),
            #("claimed_count", json.int(overview.claimed_count)),
            #("ongoing_count", json.int(overview.ongoing_count)),
            #("released_count", json.int(overview.released_count)),
            #("completed_count", json.int(overview.completed_count)),
          ]),
        ),
        #(
          "release_rate_percent",
          option_int_json(overview.release_rate_percent),
        ),
        #(
          "pool_flow_ratio_percent",
          option_int_json(overview.pool_flow_ratio_percent),
        ),
        #(
          "time_to_first_claim",
          json.object([
            #("p50_ms", option_int_json(overview.time_to_first_claim_p50_ms)),
            #("sample_size", json.int(overview.time_to_first_claim_sample_size)),
          ]),
        ),
        #(
          "time_to_first_claim_buckets",
          json.array(overview.time_to_first_claim_buckets, of: bucket_json),
        ),
        #(
          "release_rate_buckets",
          json.array(overview.release_rate_buckets, of: bucket_json),
        ),
        #("wip_count", json.int(overview.wip_count)),
        #(
          "avg_claim_to_complete_ms",
          option_int_json(overview.avg_claim_to_complete_ms),
        ),
        #(
          "avg_time_in_claimed_ms",
          option_int_json(overview.avg_time_in_claimed_ms),
        ),
        #("stale_claims_count", json.int(overview.stale_claims_count)),
        #(
          "by_project",
          json.array(overview.by_project, of: project_metrics_json),
        ),
      ]),
    ),
  ])
}

fn bucket_json(bucket: TimeToFirstClaimBucket) -> json.Json {
  json.object([
    #("bucket", json.string(bucket.bucket)),
    #("count", json.int(bucket.count)),
  ])
}

fn project_metrics_json(row: ProjectMetricsRow) -> json.Json {
  json.object([
    #("project_id", json.int(row.project_id)),
    #("project_name", json.string(row.project_name)),
    #("available_count", json.int(row.available_count)),
    #("claimed_count", json.int(row.claimed_count)),
    #("ongoing_count", json.int(row.ongoing_count)),
    #("released_count", json.int(row.released_count)),
    #("completed_count", json.int(row.completed_count)),
    #("release_rate_percent", option_int_json(row.release_rate_percent)),
    #("pool_flow_ratio_percent", option_int_json(row.pool_flow_ratio_percent)),
    #("wip_count", json.int(row.wip_count)),
    #("avg_claim_to_complete_ms", option_int_json(row.avg_claim_to_complete_ms)),
    #("avg_time_in_claimed_ms", option_int_json(row.avg_time_in_claimed_ms)),
    #("stale_claims_count", json.int(row.stale_claims_count)),
  ])
}

// =============================================================================
// Project Tasks Presenters
// =============================================================================

/// Convert project tasks response to JSON.
pub fn project_tasks_json(
  window_days: Int,
  project_id: Int,
  tasks: List(ProjectTask),
) -> json.Json {
  json.object([
    #("window_days", json.int(window_days)),
    #("project_id", json.int(project_id)),
    #("tasks", json.array(tasks, of: project_task_json)),
  ])
}

fn project_task_json(task: ProjectTask) -> json.Json {
  json.object([
    #("id", json.int(task.id)),
    #("project_id", json.int(task.project_id)),
    #("type_id", json.int(task.type_id)),
    #(
      "task_type",
      json.object([
        #("id", json.int(task.type_id)),
        #("name", json.string(task.type_name)),
        #("icon", json.string(task.type_icon)),
      ]),
    ),
    #("ongoing_by", ongoing_by_json(task.ongoing_by_user_id)),
    #("title", json.string(task.title)),
    #("description", json.string(task.description)),
    #("priority", json.int(task.priority)),
    #("status", json.string(task.status)),
    #("work_state", json.string(work_state_to_string(task.work_state))),
    #("created_by", json.int(task.created_by)),
    #("claimed_by", option_int_json(task.claimed_by)),
    #("claimed_at", option_string_json(task.claimed_at)),
    #("completed_at", option_string_json(task.completed_at)),
    #("created_at", json.string(task.created_at)),
    #("version", json.int(task.version)),
    #("claim_count", json.int(task.claim_count)),
    #("release_count", json.int(task.release_count)),
    #("complete_count", json.int(task.complete_count)),
    #("first_claim_at", option_string_json(task.first_claim_at)),
  ])
}

// =============================================================================
// User Metrics Presenters
// =============================================================================

pub fn users_overview_json(users: List(UserMetricsRow)) -> json.Json {
  json.object([
    #("users", json.array(users, of: user_metrics_json)),
  ])
}

fn user_metrics_json(row: UserMetricsRow) -> json.Json {
  json.object([
    #("user_id", json.int(row.user_id)),
    #("email", json.string(row.email)),
    #("claimed_count", json.int(row.claimed_count)),
    #("released_count", json.int(row.released_count)),
    #("completed_count", json.int(row.completed_count)),
    #("ongoing_count", json.int(row.ongoing_count)),
    #("last_claim_at", option_string_json(row.last_claim_at)),
  ])
}

// =============================================================================
// Helpers (re-exported from shared/helpers/json for backwards compatibility)
// =============================================================================

/// Convert optional int to JSON (null or number).
/// Re-exported from shared/helpers/json.
pub const option_int_json = json_helpers.option_int_json

/// Convert optional string to JSON (null or string).
/// Re-exported from shared/helpers/json.
pub const option_string_json = json_helpers.option_string_json

fn ongoing_by_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(user_id) -> json.object([#("user_id", json.int(user_id))])
  }
}
