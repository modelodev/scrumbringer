//// Metrics business logic and data types.
////
//// ## Mission
////
//// Provides domain types and business logic for metrics calculations.
//// Orchestrates database queries and transforms raw data into domain models.
////
//// ## Responsibilities
////
//// - Define metrics domain types
//// - Calculate derived metrics (percentages, ratios)
//// - Orchestrate data fetching from SQL layer
////
//// ## Non-responsibilities
////
//// - SQL query definitions (see `sql.gleam`)
//// - JSON serialization (see `metrics_presenters.gleam`)
//// - HTTP handling (see `org_metrics.gleam`)

import domain/task_status
import gleam/int
import gleam/option.{type Option, None, Some}
import pog

import scrumbringer_server/sql

// =============================================================================
// Types
// =============================================================================

/// Bucket for time distribution histograms.
pub type TimeToFirstClaimBucket {
  TimeToFirstClaimBucket(bucket: String, count: Int)
}

/// Per-project metrics row.
pub type ProjectMetricsRow {
  ProjectMetricsRow(
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

/// Complete metrics overview.
pub type MetricsOverview {
  MetricsOverview(
    window_days: Int,
    available_count: Int,
    claimed_count: Int,
    ongoing_count: Int,
    released_count: Int,
    completed_count: Int,
    release_rate_percent: Option(Int),
    pool_flow_ratio_percent: Option(Int),
    time_to_first_claim_p50_ms: Option(Int),
    time_to_first_claim_sample_size: Int,
    time_to_first_claim_buckets: List(TimeToFirstClaimBucket),
    release_rate_buckets: List(TimeToFirstClaimBucket),
    wip_count: Int,
    avg_claim_to_complete_ms: Option(Int),
    avg_time_in_claimed_ms: Option(Int),
    stale_claims_count: Int,
    by_project: List(ProjectMetricsRow),
  )
}

/// Per-user metrics row.
pub type UserMetricsRow {
  UserMetricsRow(
    user_id: Int,
    email: String,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
    ongoing_count: Int,
    last_claim_at: Option(String),
  )
}

/// Project task with metrics.
pub type ProjectTask {
  ProjectTask(
    id: Int,
    project_id: Int,
    type_id: Int,
    type_name: String,
    type_icon: String,
    ongoing_by_user_id: Option(Int),
    title: String,
    description: String,
    priority: Int,
    status: String,
    work_state: WorkState,
    created_by: Int,
    claimed_by: Option(Int),
    claimed_at: Option(String),
    completed_at: Option(String),
    created_at: String,
    version: Int,
    claim_count: Int,
    release_count: Int,
    complete_count: Int,
    first_claim_at: Option(String),
  )
}

/// Work state ADT for derived task status.
pub type WorkState =
  task_status.WorkState

/// Error type for metrics operations.
pub type MetricsError {
  DbError(pog.QueryError)
  NotFound
}

// =============================================================================
// Service Functions
// =============================================================================

/// Fetch organization overview metrics.
pub fn get_org_overview(
  db: pog.Connection,
  org_id: Int,
  window_days: Int,
) -> Result(MetricsOverview, MetricsError) {
  let window_days_str = int.to_string(window_days)

  let totals = sql.metrics_org_overview(db, org_id, window_days_str)
  let buckets_claim =
    sql.metrics_time_to_first_claim_buckets(db, org_id, window_days_str)
  let p50 = sql.metrics_time_to_first_claim_p50_ms(db, org_id, window_days_str)
  let buckets_release =
    sql.metrics_release_rate_buckets(db, org_id, window_days_str)
  let by_project =
    sql.metrics_org_overview_by_project(db, org_id, window_days_str)

  case totals, buckets_claim, p50, buckets_release, by_project {
    Ok(pog.Returned(rows: [totals_row, ..], ..)),
      Ok(pog.Returned(rows: ttf_buckets, ..)),
      Ok(pog.Returned(rows: [p50_row, ..], ..)),
      Ok(pog.Returned(rows: rr_buckets, ..)),
      Ok(pog.Returned(rows: project_rows, ..))
    -> {
      let claimed = totals_row.claimed_count
      let released = totals_row.released_count
      let completed = totals_row.completed_count
      let available = totals_row.available_count
      let ongoing = totals_row.ongoing_count
      let wip_count = totals_row.wip_count

      let release_rate_percent = percent(released, claimed)
      let pool_flow_ratio_percent = percent(completed, claimed)

      let time_to_first_claim_p50_ms = case p50_row.sample_size {
        0 -> None
        _ -> Some(p50_row.p50_ms)
      }

      let ttf_buckets_mapped =
        ttf_buckets
        |> map_buckets

      let rr_buckets_mapped =
        rr_buckets
        |> map_release_rate_buckets

      let project_rows_mapped =
        project_rows
        |> map_project_rows

      let avg_claim_to_complete_ms = case totals_row.avg_claim_to_complete_ms {
        0 -> None
        value -> Some(value)
      }

      let avg_time_in_claimed_ms = case totals_row.avg_time_in_claimed_ms {
        0 -> None
        value -> Some(value)
      }

      Ok(MetricsOverview(
        window_days: window_days,
        available_count: available,
        claimed_count: claimed,
        ongoing_count: ongoing,
        released_count: released,
        completed_count: completed,
        release_rate_percent: release_rate_percent,
        pool_flow_ratio_percent: pool_flow_ratio_percent,
        time_to_first_claim_p50_ms: time_to_first_claim_p50_ms,
        time_to_first_claim_sample_size: p50_row.sample_size,
        time_to_first_claim_buckets: ttf_buckets_mapped,
        release_rate_buckets: rr_buckets_mapped,
        wip_count: wip_count,
        avg_claim_to_complete_ms: avg_claim_to_complete_ms,
        avg_time_in_claimed_ms: avg_time_in_claimed_ms,
        stale_claims_count: totals_row.stale_claims_count,
        by_project: project_rows_mapped,
      ))
    }

    Error(e), _, _, _, _ -> Error(DbError(e))
    _, Error(e), _, _, _ -> Error(DbError(e))
    _, _, Error(e), _, _ -> Error(DbError(e))
    _, _, _, Error(e), _ -> Error(DbError(e))
    _, _, _, _, Error(e) -> Error(DbError(e))
    _, _, _, _, _ -> Error(NotFound)
  }
}

/// Fetch project tasks with metrics.
pub fn get_project_tasks(
  db: pog.Connection,
  project_id: Int,
  window_days: Int,
) -> Result(List(ProjectTask), MetricsError) {
  case sql.metrics_project_tasks(db, project_id, int.to_string(window_days)) {
    Ok(pog.Returned(rows: rows, ..)) -> Ok(rows |> map_project_tasks)
    Error(e) -> Error(DbError(e))
  }
}

/// Fetch per-user metrics overview for org.
pub fn get_users_overview(
  db: pog.Connection,
  org_id: Int,
  window_days: Int,
) -> Result(List(UserMetricsRow), MetricsError) {
  case sql.metrics_users_overview(db, org_id, int.to_string(window_days)) {
    Ok(pog.Returned(rows: rows, ..)) -> Ok(rows |> map_user_rows)
    Error(e) -> Error(DbError(e))
  }
}

/// Check if a project belongs to an organization.
pub fn verify_project_org(
  db: pog.Connection,
  project_id: Int,
  org_id: Int,
) -> Result(Bool, MetricsError) {
  case sql.projects_org_id(db, project_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row.org_id == org_id)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

// =============================================================================
// Private Helpers
// =============================================================================

fn map_buckets(
  rows: List(sql.MetricsTimeToFirstClaimBucketsRow),
) -> List(TimeToFirstClaimBucket) {
  rows
  |> do_map_buckets([])
}

fn do_map_buckets(
  rows: List(sql.MetricsTimeToFirstClaimBucketsRow),
  acc: List(TimeToFirstClaimBucket),
) -> List(TimeToFirstClaimBucket) {
  case rows {
    [] -> reverse(acc)
    [row, ..rest] ->
      do_map_buckets(rest, [
        TimeToFirstClaimBucket(bucket: row.bucket, count: row.count),
        ..acc
      ])
  }
}

fn map_release_rate_buckets(
  rows: List(sql.MetricsReleaseRateBucketsRow),
) -> List(TimeToFirstClaimBucket) {
  rows
  |> do_map_release_rate_buckets([])
}

fn do_map_release_rate_buckets(
  rows: List(sql.MetricsReleaseRateBucketsRow),
  acc: List(TimeToFirstClaimBucket),
) -> List(TimeToFirstClaimBucket) {
  case rows {
    [] -> reverse(acc)
    [row, ..rest] ->
      do_map_release_rate_buckets(rest, [
        TimeToFirstClaimBucket(bucket: row.bucket, count: row.count),
        ..acc
      ])
  }
}

fn map_project_rows(
  rows: List(sql.MetricsOrgOverviewByProjectRow),
) -> List(ProjectMetricsRow) {
  rows
  |> do_map_project_rows([])
}

fn do_map_project_rows(
  rows: List(sql.MetricsOrgOverviewByProjectRow),
  acc: List(ProjectMetricsRow),
) -> List(ProjectMetricsRow) {
  case rows {
    [] -> reverse(acc)
    [row, ..rest] -> {
      let project_release_rate_percent =
        percent(row.released_count, row.claimed_count)
      let project_pool_flow_ratio_percent =
        percent(row.completed_count, row.claimed_count)

      do_map_project_rows(rest, [
        ProjectMetricsRow(
          project_id: row.project_id,
          project_name: row.project_name,
          available_count: row.available_count,
          claimed_count: row.claimed_count,
          ongoing_count: row.ongoing_count,
          released_count: row.released_count,
          completed_count: row.completed_count,
          release_rate_percent: project_release_rate_percent,
          pool_flow_ratio_percent: project_pool_flow_ratio_percent,
          wip_count: row.wip_count,
          avg_claim_to_complete_ms: row.avg_claim_to_complete_ms,
          avg_time_in_claimed_ms: row.avg_time_in_claimed_ms,
          stale_claims_count: row.stale_claims_count,
        ),
        ..acc
      ])
    }
  }
}

fn map_user_rows(
  rows: List(sql.MetricsUsersOverviewRow),
) -> List(UserMetricsRow) {
  rows
  |> do_map_user_rows([])
}

fn do_map_user_rows(
  rows: List(sql.MetricsUsersOverviewRow),
  acc: List(UserMetricsRow),
) -> List(UserMetricsRow) {
  case rows {
    [] -> reverse(acc)
    [row, ..rest] -> {
      let last_claim_at = empty_string_to_option(row.last_claim_at)
      do_map_user_rows(rest, [
        UserMetricsRow(
          user_id: row.user_id,
          email: row.email,
          claimed_count: row.claimed_count,
          released_count: row.released_count,
          completed_count: row.completed_count,
          ongoing_count: row.ongoing_count,
          last_claim_at: last_claim_at,
        ),
        ..acc
      ])
    }
  }
}

fn map_project_tasks(
  rows: List(sql.MetricsProjectTasksRow),
) -> List(ProjectTask) {
  rows
  |> do_map_project_tasks([])
}

fn do_map_project_tasks(
  rows: List(sql.MetricsProjectTasksRow),
  acc: List(ProjectTask),
) -> List(ProjectTask) {
  case rows {
    [] -> reverse(acc)
    [row, ..rest] -> {
      let claimed_by = case row.claimed_by {
        0 -> None
        other -> Some(other)
      }

      let ongoing_by_user_id = case row.ongoing_by_user_id {
        0 -> None
        other -> Some(other)
      }

      let claimed_at = empty_string_to_option(row.claimed_at)
      let completed_at = empty_string_to_option(row.completed_at)
      let first_claim_at = empty_string_to_option(row.first_claim_at)

      let work_state = work_state_from(row.status, row.is_ongoing)

      do_map_project_tasks(rest, [
        ProjectTask(
          id: row.id,
          project_id: row.project_id,
          type_id: row.type_id,
          type_name: row.type_name,
          type_icon: row.type_icon,
          ongoing_by_user_id: ongoing_by_user_id,
          title: row.title,
          description: row.description,
          priority: row.priority,
          status: row.status,
          work_state: work_state,
          created_by: row.created_by,
          claimed_by: claimed_by,
          claimed_at: claimed_at,
          completed_at: completed_at,
          created_at: row.created_at,
          version: row.version,
          claim_count: row.claim_count,
          release_count: row.release_count,
          complete_count: row.complete_count,
          first_claim_at: first_claim_at,
        ),
        ..acc
      ])
    }
  }
}

fn reverse(list: List(a)) -> List(a) {
  do_reverse(list, [])
}

fn do_reverse(list: List(a), acc: List(a)) -> List(a) {
  case list {
    [] -> acc
    [head, ..tail] -> do_reverse(tail, [head, ..acc])
  }
}

fn percent(numerator: Int, denominator: Int) -> Option(Int) {
  case denominator {
    0 -> None
    _ -> Some(numerator * 100 / denominator)
  }
}

fn empty_string_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    other -> Some(other)
  }
}

// Justification: nested case improves clarity for branching logic.
/// Derive work state from status and ongoing flag.
pub fn work_state_from(status: String, is_ongoing: Bool) -> WorkState {
  case status {
    "available" -> task_status.WorkAvailable
    "completed" -> task_status.WorkCompleted
    "claimed" ->
      // Justification: nested case disambiguates claimed vs ongoing states.
      case is_ongoing {
        True -> task_status.WorkOngoing
        False -> task_status.WorkClaimed
      }
    _ -> task_status.WorkClaimed
  }
}

/// Converts a work state to its wire/string representation.
///
/// Example:
///   work_state_to_string(task_status.WorkAvailable)
pub fn work_state_to_string(state: WorkState) -> String {
  case state {
    task_status.WorkAvailable -> "available"
    task_status.WorkClaimed -> "claimed"
    task_status.WorkOngoing -> "ongoing"
    task_status.WorkCompleted -> "completed"
  }
}
