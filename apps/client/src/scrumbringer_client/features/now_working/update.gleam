//// Now Working workflow for Scrumbringer client.
////
//// ## Mission
////
//// Manages the "now working" timer feature that tracks active task time.
//// Handles start/pause actions, heartbeat synchronization, and tick updates.
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
//// - API request construction (see `api/tasks.gleam`)
//// - View rendering (see `client_view.gleam`)
//// - Model type definitions (see `client_state.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates now_working messages here
//// - **api/tasks.gleam**: Provides work session API functions
//// - **update_helpers.gleam**: Provides now_working_active_task helper

import gleam/option as opt

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks as api_tasks

// Domain types
import domain/api_error.{type ApiError}
import domain/remote.{Failed, Loaded}
import domain/task.{type WorkSessionsPayload, WorkSessionsPayload}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, pool_msg, update_member,
}
import scrumbringer_client/client_state/member.{MemberModel}
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/update_helpers

// =============================================================================
// Message Handlers
// =============================================================================

/// Handle start button click - begins tracking time on a task.
pub fn handle_start_clicked(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  case model.member.member_now_working_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model =
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_now_working_in_flight: True,
            member_now_working_error: opt.None,
          )
        })
      #(
        model,
        api_tasks.start_work_session(task_id, fn(result) -> Msg {
          pool_msg(pool_messages.MemberWorkSessionStarted(result))
        }),
      )
    }
  }
}

// Justification: nested case improves clarity for branching logic.
/// Handle pause button click - stops tracking time.
pub fn handle_pause_clicked(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.member_now_working_in_flight {
    True -> #(model, effect.none())
    False -> {
      // Get active task_id from work sessions
      case get_first_active_session_task_id(model) {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> {
          let model =
            update_member(model, fn(member) {
              MemberModel(
                ..member,
                member_now_working_in_flight: True,
                member_now_working_error: opt.None,
              )
            })
          #(
            model,
            api_tasks.pause_work_session(task_id, fn(result) -> Msg {
              pool_msg(pool_messages.MemberWorkSessionPaused(result))
            }),
          )
        }
      }
    }
  }
}

/// Get task_id of first active work session.
fn get_first_active_session_task_id(model: Model) -> opt.Option(Int) {
  case model.member.member_work_sessions {
    Loaded(WorkSessionsPayload(active_sessions: [first, ..], ..)) ->
      opt.Some(first.task_id)
    _ -> opt.None
  }
}

/// Handle timer tick - updates tick counter and sends heartbeat every 60 ticks.
pub fn handle_ticked(model: Model) -> #(Model, Effect(Msg)) {
  let next_tick = model.member.now_working_tick + 1
  let model =
    update_member(model, fn(member) {
      MemberModel(..member, now_working_tick: next_tick)
    })

  // Check if there's an active work session
  let active_task_id = get_first_active_session_task_id(model)

  let heartbeat_fx = case
    next_tick % 60 == 0
    && model.member.member_now_working_in_flight == False
    && active_task_id != opt.None
  {
    True ->
      case active_task_id {
        opt.Some(task_id) ->
          api_tasks.heartbeat_work_session(task_id, fn(result) -> Msg {
            pool_msg(pool_messages.MemberWorkSessionHeartbeated(result))
          })
        opt.None -> effect.none()
      }
    False -> effect.none()
  }

  case active_task_id {
    opt.Some(_) -> #(model, effect.batch([tick_effect(), heartbeat_fx]))
    opt.None -> #(
      update_member(model, fn(member) {
        MemberModel(..member, now_working_tick_running: False)
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Effects
// =============================================================================

/// Create effect that schedules the next tick in 1 second.
pub fn tick_effect() -> Effect(Msg) {
  app_effects.schedule_timeout(1000, fn() {
    pool_msg(pool_messages.NowWorkingTicked)
  })
}

// Justification: nested case improves clarity for branching logic.
/// Start tick timer if not already running and there's an active task.
pub fn start_tick_if_needed(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.now_working_tick_running {
    True -> #(model, effect.none())

    False ->
      case update_helpers.now_working_active_task(model) {
        opt.Some(_) -> #(
          update_member(model, fn(member) {
            MemberModel(..member, now_working_tick_running: True)
          }),
          tick_effect(),
        )
        opt.None -> #(model, effect.none())
      }
  }
}

// =============================================================================
// Work Sessions Handlers (Multi-Session Model)
// =============================================================================

/// Handle successful work sessions fetch response.
pub fn handle_sessions_fetched_ok(
  model: Model,
  payload: WorkSessionsPayload,
) -> #(Model, Effect(Msg)) {
  apply_sessions_payload(model, payload)
  |> start_tick_if_sessions_needed
}

/// Handle failed work sessions fetch response.
pub fn handle_sessions_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  handle_sessions_error(model, err)
}

/// Handle successful work session start response.
pub fn handle_session_started_ok(
  model: Model,
  payload: WorkSessionsPayload,
) -> #(Model, Effect(Msg)) {
  update_member(apply_sessions_payload(model, payload), fn(member) {
    MemberModel(..member, member_now_working_in_flight: False)
  })
  |> start_tick_if_sessions_needed
}

/// Handle failed work session start response.
pub fn handle_session_started_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  handle_sessions_toast_error(model, err)
}

/// Handle successful work session pause response.
pub fn handle_session_paused_ok(
  model: Model,
  payload: WorkSessionsPayload,
) -> #(Model, Effect(Msg)) {
  let WorkSessionsPayload(active_sessions: sessions, ..) = payload

  let model =
    update_member(apply_sessions_payload(model, payload), fn(member) {
      MemberModel(..member, member_now_working_in_flight: False)
    })

  // Stop tick if no more active sessions
  case sessions {
    [] -> #(
      update_member(model, fn(member) {
        MemberModel(..member, now_working_tick_running: False)
      }),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

/// Handle failed work session pause response.
pub fn handle_session_paused_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  handle_sessions_toast_error(model, err)
}

/// Handle successful work session heartbeat response.
pub fn handle_session_heartbeated_ok(
  model: Model,
  payload: WorkSessionsPayload,
) -> #(Model, Effect(Msg)) {
  apply_sessions_payload(model, payload)
  |> start_tick_if_sessions_needed
}

/// Handle failed work session heartbeat response.
pub fn handle_session_heartbeated_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  handle_sessions_noop_error(model, err)
}

fn apply_sessions_payload(model: Model, payload: WorkSessionsPayload) -> Model {
  let WorkSessionsPayload(as_of: as_of, ..) = payload
  let server_ms = client_ffi.parse_iso_ms(as_of)
  let offset = client_ffi.now_ms() - server_ms

  update_member(model, fn(member) {
    MemberModel(
      ..member,
      member_work_sessions: Loaded(payload),
      now_working_server_offset_ms: offset,
    )
  })
}

fn handle_sessions_error(model: Model, err: ApiError) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_member(model, fn(member) {
        MemberModel(..member, member_work_sessions: Failed(err))
      }),
      effect.none(),
    )
  })
}

fn handle_sessions_toast_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(..member, member_now_working_in_flight: False)
    })

  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_member(model, fn(member) {
        MemberModel(..member, member_now_working_error: opt.Some(err.message))
      }),
      update_helpers.toast_error(err.message),
    )
  })
}

fn handle_sessions_noop_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() { #(model, effect.none()) })
}

// Justification: nested case improves clarity for branching logic.
/// Start tick timer if not already running and there are active sessions.
fn start_tick_if_sessions_needed(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.now_working_tick_running {
    True -> #(model, effect.none())

    False ->
      case model.member.member_work_sessions {
        Loaded(WorkSessionsPayload(active_sessions: [_, ..], ..)) -> #(
          update_member(model, fn(member) {
            MemberModel(..member, now_working_tick_running: True)
          }),
          tick_effect(),
        )
        _ -> #(model, effect.none())
      }
  }
}
