//// Now Working update flow for Scrumbringer client.
////
//// ## Mission
////
//// Manages the local "now working" timer state and work-session payload state.
////
//// ## Responsibilities
////
//// - Handle start/pause button clicks
//// - Process API responses for work session operations
//// - Manage timer tick and heartbeat synchronization
//// - Track server time offset for accurate elapsed time display
////
//// ## Non-responsibilities
////
//// - Root model assembly (see `features/pool/update.gleam`)
//// - Authentication handling (see `features/pool/update.gleam`)
//// - View rendering (see `features/now_working/panel.gleam`, `mobile.gleam`)
////
//// ## Relations
////
//// - **features/pool/update.gleam**: Applies local transitions to the root model
//// - **api/tasks/active.gleam**: Provides work session API functions

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/remote.{Failed, Loaded}
import domain/task.{type WorkSessionsPayload, WorkSessionsPayload}
import scrumbringer_client/api/tasks/active as active_api
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/client_state/member/now_working as member_now_working
import scrumbringer_client/features/pool/msg as pool_messages

pub type Model {
  Model(now_working: member_now_working.Model, metrics: member_metrics.Model)
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuthBefore(ApiError)
  CheckAuthAfter(ApiError)
}

pub type Update(parent_msg) {
  Update(Model, Effect(parent_msg), AuthPolicy)
}

pub type Context(parent_msg) {
  Context(
    on_session_started: fn(ApiResult(WorkSessionsPayload)) -> parent_msg,
    on_session_paused: fn(ApiResult(WorkSessionsPayload)) -> parent_msg,
    on_session_heartbeated: fn(ApiResult(WorkSessionsPayload)) -> parent_msg,
    on_tick: fn() -> parent_msg,
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

// =============================================================================
// Message Handlers
// =============================================================================

pub fn try_update(
  model: Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberNowWorkingStartClicked(task_id) ->
      handle_start_clicked(model, task_id, context)
      |> without_auth_check

    pool_messages.MemberNowWorkingPauseClicked ->
      handle_pause_clicked(model, context)
      |> without_auth_check

    pool_messages.MemberWorkSessionsFetched(Ok(payload)) ->
      handle_sessions_fetched_ok(model, payload, context)
      |> without_auth_check

    pool_messages.MemberWorkSessionsFetched(Error(err)) ->
      handle_sessions_fetched_error(model, err)
      |> with_auth_check_before(err)

    pool_messages.MemberWorkSessionStarted(Ok(payload)) ->
      handle_session_started_ok(model, payload, context)
      |> without_auth_check

    pool_messages.MemberWorkSessionStarted(Error(err)) ->
      handle_session_started_error(model, err, context)
      |> with_auth_check_after(err)

    pool_messages.MemberWorkSessionPaused(Ok(payload)) ->
      handle_session_paused_ok(model, payload)
      |> without_auth_check

    pool_messages.MemberWorkSessionPaused(Error(err)) ->
      handle_session_paused_error(model, err, context)
      |> with_auth_check_after(err)

    pool_messages.MemberWorkSessionHeartbeated(Ok(payload)) ->
      handle_session_heartbeated_ok(model, payload, context)
      |> without_auth_check

    pool_messages.MemberWorkSessionHeartbeated(Error(err)) ->
      handle_session_heartbeated_error(model, err)
      |> with_auth_check_before(err)

    pool_messages.NowWorkingTicked ->
      handle_ticked(model, context)
      |> without_auth_check

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, NoAuthCheck))
}

fn with_auth_check_before(
  result: #(Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, CheckAuthBefore(err)))
}

fn with_auth_check_after(
  result: #(Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, CheckAuthAfter(err)))
}

/// Handle start button click - begins tracking time on a task.
fn handle_start_clicked(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case model.now_working.member_now_working_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model = begin_work_session_request(model)
      #(
        model,
        active_api.start_work_session(task_id, context.on_session_started),
      )
    }
  }
}

/// Handle pause button click - stops tracking time.
fn handle_pause_clicked(
  model: Model,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case model.now_working.member_now_working_in_flight {
    True -> #(model, effect.none())
    False -> {
      case active_session_task_id(model.metrics) {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> {
          let model = begin_work_session_request(model)
          #(
            model,
            active_api.pause_work_session(task_id, context.on_session_paused),
          )
        }
      }
    }
  }
}

/// Handle timer tick - updates tick counter and sends heartbeat every 60 ticks.
fn handle_ticked(
  model: Model,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let next_tick = model.now_working.now_working_tick + 1
  let model =
    update_now_working(model, fn(now_working) {
      member_now_working.Model(..now_working, now_working_tick: next_tick)
    })

  let active_task_id = active_session_task_id(model.metrics)
  let heartbeat_fx = case
    next_tick % 60 == 0,
    model.now_working.member_now_working_in_flight,
    active_task_id
  {
    True, False, opt.Some(task_id) ->
      active_api.heartbeat_work_session(task_id, context.on_session_heartbeated)
    _, _, _ -> effect.none()
  }

  case active_task_id {
    opt.Some(_) -> #(
      model,
      effect.batch([schedule_tick(context), heartbeat_fx]),
    )
    opt.None -> #(
      update_now_working(model, fn(now_working) {
        member_now_working.Model(..now_working, now_working_tick_running: False)
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Effects
// =============================================================================

/// Create effect that schedules the next tick in 1 second.
fn schedule_tick(context: Context(parent_msg)) -> Effect(parent_msg) {
  app_effects.schedule_timeout(1000, context.on_tick)
}

// =============================================================================
// Work Sessions Handlers (Multi-Session Model)
// =============================================================================

/// Handle successful work sessions fetch response.
fn handle_sessions_fetched_ok(
  model: Model,
  payload: WorkSessionsPayload,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  apply_sessions_payload(model, payload)
  |> start_tick_if_sessions_needed(context)
}

/// Handle failed work sessions fetch response.
fn handle_sessions_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(parent_msg)) {
  #(
    update_member_metrics(model, fn(metrics) {
      member_metrics.Model(..metrics, member_work_sessions: Failed(err))
    }),
    effect.none(),
  )
}

/// Handle successful work session start response.
fn handle_session_started_ok(
  model: Model,
  payload: WorkSessionsPayload,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  finish_work_session_request(apply_sessions_payload(model, payload))
  |> start_tick_if_sessions_needed(context)
}

/// Handle failed work session start response.
fn handle_session_started_error(
  model: Model,
  err: ApiError,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  handle_sessions_error(model, err, context)
}

/// Handle successful work session pause response.
fn handle_session_paused_ok(
  model: Model,
  payload: WorkSessionsPayload,
) -> #(Model, Effect(parent_msg)) {
  let WorkSessionsPayload(active_sessions: sessions, ..) = payload

  let model =
    finish_work_session_request(apply_sessions_payload(model, payload))

  case sessions {
    [] -> #(
      update_now_working(model, fn(now_working) {
        member_now_working.Model(..now_working, now_working_tick_running: False)
      }),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

/// Handle failed work session pause response.
fn handle_session_paused_error(
  model: Model,
  err: ApiError,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  handle_sessions_error(model, err, context)
}

/// Handle successful work session heartbeat response.
fn handle_session_heartbeated_ok(
  model: Model,
  payload: WorkSessionsPayload,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  apply_sessions_payload(model, payload)
  |> start_tick_if_sessions_needed(context)
}

/// Handle failed work session heartbeat response.
fn handle_session_heartbeated_error(
  model: Model,
  _err: ApiError,
) -> #(Model, Effect(parent_msg)) {
  #(model, effect.none())
}

fn apply_sessions_payload(model: Model, payload: WorkSessionsPayload) -> Model {
  let WorkSessionsPayload(as_of: as_of, ..) = payload
  let server_ms = client_ffi.parse_iso_ms(as_of)
  let offset = client_ffi.now_ms() - server_ms

  Model(
    metrics: member_metrics.Model(
      ..model.metrics,
      member_work_sessions: Loaded(payload),
    ),
    now_working: member_now_working.Model(
      ..model.now_working,
      now_working_server_offset_ms: offset,
    ),
  )
}

fn handle_sessions_error(
  model: Model,
  err: ApiError,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  #(
    update_now_working(model, fn(now_working) {
      member_now_working.Model(
        ..now_working,
        member_now_working_in_flight: False,
        member_now_working_error: opt.Some(err.message),
      )
    }),
    context.on_error_toast(err.message),
  )
}

/// Start tick timer if not already running and there are active sessions.
fn start_tick_if_sessions_needed(
  model: Model,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case model.now_working.now_working_tick_running {
    True -> #(model, effect.none())

    False ->
      case active_session_task_id(model.metrics) {
        opt.Some(_) -> #(
          update_now_working(model, fn(now_working) {
            member_now_working.Model(
              ..now_working,
              now_working_tick_running: True,
            )
          }),
          schedule_tick(context),
        )
        opt.None -> #(model, effect.none())
      }
  }
}

fn active_session_task_id(metrics: member_metrics.Model) -> opt.Option(Int) {
  case metrics.member_work_sessions {
    Loaded(WorkSessionsPayload(active_sessions: [first, ..], ..)) ->
      opt.Some(first.task_id)
    _ -> opt.None
  }
}

fn update_now_working(
  model: Model,
  f: fn(member_now_working.Model) -> member_now_working.Model,
) -> Model {
  Model(..model, now_working: f(model.now_working))
}

fn update_member_metrics(
  model: Model,
  f: fn(member_metrics.Model) -> member_metrics.Model,
) -> Model {
  Model(..model, metrics: f(model.metrics))
}

fn begin_work_session_request(model: Model) -> Model {
  update_now_working(model, fn(now_working) {
    member_now_working.Model(
      ..now_working,
      member_now_working_in_flight: True,
      member_now_working_error: opt.None,
    )
  })
}

fn finish_work_session_request(model: Model) -> Model {
  update_now_working(model, fn(now_working) {
    member_now_working.Model(..now_working, member_now_working_in_flight: False)
  })
}
