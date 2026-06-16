//// Metrics feature update handlers for Scrumbringer client.
////
//// ## Mission
////
//// Handle metrics-related state transitions for both member and admin views.
////
//// ## Responsibilities
////
//// - Handle member metrics fetch responses
//// - Handle admin metrics overview fetch responses
//// - Handle admin metrics project tasks fetch responses
////
//// ## Non-responsibilities
////
//// - API request construction (see `api/operational_metrics.gleam`)
//// - View rendering (see `features/metrics/view.gleam`)
////
//// ## Relations
////
//// - **features/pool/update.gleam**: Applies local transitions to the root model

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/metrics.{
  type MyMetrics, type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  type OrgMetricsUserOverview, OrgMetricsProjectTasksPayload,
}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/features/pool/msg as pool_messages

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  MemberUpdate(member_metrics.Model, Effect(parent_msg), AuthPolicy)
  AdminUpdate(admin_metrics.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  member: member_metrics.Model,
  admin: admin_metrics.Model,
  inner: pool_messages.Msg,
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberMetricsFetched(Ok(metrics)) -> {
      let #(next, fx) = handle_member_metrics_fetched_ok(member, metrics)
      opt.Some(MemberUpdate(next, fx, NoAuthCheck))
    }
    pool_messages.MemberMetricsFetched(Error(err)) -> {
      let #(next, fx) = handle_member_metrics_fetched_error(member, err)
      opt.Some(MemberUpdate(next, fx, CheckAuth(err)))
    }
    pool_messages.AdminMetricsOverviewFetched(Ok(overview)) -> {
      let #(next, fx) = handle_admin_overview_fetched_ok(admin, overview)
      opt.Some(AdminUpdate(next, fx, NoAuthCheck))
    }
    pool_messages.AdminMetricsOverviewFetched(Error(err)) -> {
      let #(next, fx) = handle_admin_overview_fetched_error(admin, err)
      opt.Some(AdminUpdate(next, fx, CheckAuth(err)))
    }
    pool_messages.AdminMetricsProjectTasksFetched(Ok(payload)) -> {
      let #(next, fx) = handle_admin_project_tasks_fetched_ok(admin, payload)
      opt.Some(AdminUpdate(next, fx, NoAuthCheck))
    }
    pool_messages.AdminMetricsProjectTasksFetched(Error(err)) -> {
      let #(next, fx) = handle_admin_project_tasks_fetched_error(admin, err)
      opt.Some(AdminUpdate(next, fx, CheckAuth(err)))
    }
    pool_messages.AdminMetricsUsersFetched(Ok(users)) -> {
      let #(next, fx) = handle_admin_users_fetched_ok(admin, users)
      opt.Some(AdminUpdate(next, fx, NoAuthCheck))
    }
    pool_messages.AdminMetricsUsersFetched(Error(err)) -> {
      let #(next, fx) = handle_admin_users_fetched_error(admin, err)
      opt.Some(AdminUpdate(next, fx, CheckAuth(err)))
    }
    _ -> opt.None
  }
}

// =============================================================================
// Member Metrics Handlers
// =============================================================================

/// Handle successful member metrics fetch.
fn handle_member_metrics_fetched_ok(
  model: member_metrics.Model,
  metrics: MyMetrics,
) -> #(member_metrics.Model, Effect(parent_msg)) {
  #(
    member_metrics.Model(..model, member_metrics: Loaded(metrics)),
    effect.none(),
  )
}

/// Handle failed member metrics fetch.
fn handle_member_metrics_fetched_error(
  model: member_metrics.Model,
  err: ApiError,
) -> #(member_metrics.Model, Effect(parent_msg)) {
  #(member_metrics.Model(..model, member_metrics: Failed(err)), effect.none())
}

// =============================================================================
// Admin Metrics Overview Handlers
// =============================================================================

/// Handle successful admin metrics overview fetch.
fn handle_admin_overview_fetched_ok(
  model: admin_metrics.Model,
  overview: OrgMetricsOverview,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_metrics_overview: Loaded(overview)),
    effect.none(),
  )
}

/// Handle failed admin metrics overview fetch.
fn handle_admin_overview_fetched_error(
  model: admin_metrics.Model,
  err: ApiError,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_metrics_overview: Failed(err)),
    effect.none(),
  )
}

// =============================================================================
// Admin Metrics Project Tasks Handlers
// =============================================================================

/// Handle successful admin metrics project tasks fetch.
fn handle_admin_project_tasks_fetched_ok(
  model: admin_metrics.Model,
  payload: OrgMetricsProjectTasksPayload,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  let OrgMetricsProjectTasksPayload(project_id: project_id, ..) = payload

  #(
    admin_metrics.Model(
      ..model,
      admin_metrics_project_tasks: Loaded(payload),
      admin_metrics_project_id: opt.Some(project_id),
    ),
    effect.none(),
  )
}

/// Handle failed admin metrics project tasks fetch.
fn handle_admin_project_tasks_fetched_error(
  model: admin_metrics.Model,
  err: ApiError,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_metrics_project_tasks: Failed(err)),
    effect.none(),
  )
}

// =============================================================================
// Admin Metrics Users Handlers
// =============================================================================

fn handle_admin_users_fetched_ok(
  model: admin_metrics.Model,
  users: List(OrgMetricsUserOverview),
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_metrics_users: Loaded(users)),
    effect.none(),
  )
}

fn handle_admin_users_fetched_error(
  model: admin_metrics.Model,
  err: ApiError,
) -> #(admin_metrics.Model, Effect(parent_msg)) {
  #(
    admin_metrics.Model(..model, admin_metrics_users: Failed(err)),
    effect.none(),
  )
}
