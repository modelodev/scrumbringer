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
  type OrgMetricsUserOverview, OrgMetricsProjectTasksPayload,
}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/client_state.{
  type Model, type Msg, update_admin, update_member,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/helpers/auth as helpers_auth

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
      update_member_metrics(member, fn(metrics_state) {
        member_metrics.Model(..metrics_state, member_metrics: Loaded(metrics))
      })
    }),
    effect.none(),
  )
}

/// Handle failed member metrics fetch.
pub fn handle_member_metrics_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member(model, fn(member) {
        update_member_metrics(member, fn(metrics_state) {
          member_metrics.Model(..metrics_state, member_metrics: Failed(err))
        })
      }),
      effect.none(),
    )
  })
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
      update_admin_metrics(admin, fn(metrics_state) {
        admin_metrics.Model(
          ..metrics_state,
          admin_metrics_overview: Loaded(overview),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle failed admin metrics overview fetch.
pub fn handle_admin_overview_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_admin_metrics(admin, fn(metrics_state) {
          admin_metrics.Model(
            ..metrics_state,
            admin_metrics_overview: Failed(err),
          )
        })
      }),
      effect.none(),
    )
  })
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
      update_admin_metrics(admin, fn(metrics_state) {
        admin_metrics.Model(
          ..metrics_state,
          admin_metrics_project_tasks: Loaded(payload),
          admin_metrics_project_id: opt.Some(project_id),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle failed admin metrics project tasks fetch.
pub fn handle_admin_project_tasks_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_admin_metrics(admin, fn(metrics_state) {
          admin_metrics.Model(
            ..metrics_state,
            admin_metrics_project_tasks: Failed(err),
          )
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Admin Metrics Users Handlers
// =============================================================================

pub fn handle_admin_users_fetched_ok(
  model: Model,
  users: List(OrgMetricsUserOverview),
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_admin_metrics(admin, fn(metrics_state) {
        admin_metrics.Model(..metrics_state, admin_metrics_users: Loaded(users))
      })
    }),
    effect.none(),
  )
}

pub fn handle_admin_users_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_admin_metrics(admin, fn(metrics_state) {
          admin_metrics.Model(..metrics_state, admin_metrics_users: Failed(err))
        })
      }),
      effect.none(),
    )
  })
}

fn update_admin_metrics(
  admin: admin_state.AdminModel,
  f: fn(admin_metrics.Model) -> admin_metrics.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, metrics: f(admin.metrics))
}

fn update_member_metrics(
  member: member_state.MemberModel,
  f: fn(member_metrics.Model) -> member_metrics.Model,
) -> member_state.MemberModel {
  member_state.MemberModel(..member, metrics: f(member.metrics))
}
