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
//// - API request construction (see `api/metrics.gleam`)
//// - View rendering (see `features/metrics/view.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates metrics messages here

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/metrics.{
  type MyMetrics, type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  OrgMetricsProjectTasksPayload,
}
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, Failed, Loaded, MemberModel, update_admin,
  update_member,
}
import scrumbringer_client/update_helpers

// =============================================================================
// Member Metrics Handlers
// =============================================================================

/// Handle successful member metrics fetch.
pub fn handle_member_metrics_fetched_ok(
  model: Model,
  metrics: MyMetrics,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_metrics: Loaded(metrics))
    }),
    effect.none(),
  )
}

/// Handle failed member metrics fetch.
pub fn handle_member_metrics_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      update_member(model, fn(member) {
        MemberModel(..member, member_metrics: Failed(err))
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Admin Metrics Overview Handlers
// =============================================================================

/// Handle successful admin metrics overview fetch.
pub fn handle_admin_overview_fetched_ok(
  model: Model,
  overview: OrgMetricsOverview,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, admin_metrics_overview: Loaded(overview))
    }),
    effect.none(),
  )
}

/// Handle failed admin metrics overview fetch.
pub fn handle_admin_overview_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, admin_metrics_overview: Failed(err))
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Admin Metrics Project Tasks Handlers
// =============================================================================

/// Handle successful admin metrics project tasks fetch.
pub fn handle_admin_project_tasks_fetched_ok(
  model: Model,
  payload: OrgMetricsProjectTasksPayload,
) -> #(Model, Effect(Msg)) {
  let OrgMetricsProjectTasksPayload(project_id: project_id, ..) = payload

  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        admin_metrics_project_tasks: Loaded(payload),
        admin_metrics_project_id: opt.Some(project_id),
      )
    }),
    effect.none(),
  )
}

/// Handle failed admin metrics project tasks fetch.
pub fn handle_admin_project_tasks_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, admin_metrics_project_tasks: Failed(err))
      }),
      effect.none(),
    )
  }
}
