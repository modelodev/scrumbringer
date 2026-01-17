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
//// - Process API responses for active task operations
//// - Manage timer tick and heartbeat synchronization
//// - Track server time offset for accurate elapsed time display
////
//// ## Non-responsibilities
////
//// - API request construction (see `api.gleam`)
//// - View rendering (see `client_view.gleam`)
//// - Model type definitions (see `client_state.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates now_working messages here
//// - **api.gleam**: Provides active task API functions
//// - **update_helpers.gleam**: Provides now_working_active_task helper

import gleam/option as opt

import lustre/effect.{type Effect}

import scrumbringer_client/api
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Login, MemberActiveTaskHeartbeated,
  MemberActiveTaskPaused, MemberActiveTaskStarted, Model, NowWorkingTicked,
}
import scrumbringer_client/update_helpers

// =============================================================================
// Message Handlers
// =============================================================================

/// Handle start button click - begins tracking time on a task.
pub fn handle_start_clicked(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  case model.member_now_working_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model =
        Model(
          ..model,
          member_now_working_in_flight: True,
          member_now_working_error: opt.None,
        )
      #(model, api.start_me_active_task(task_id, MemberActiveTaskStarted))
    }
  }
}

/// Handle pause button click - stops tracking time.
pub fn handle_pause_clicked(model: Model) -> #(Model, Effect(Msg)) {
  case model.member_now_working_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model =
        Model(
          ..model,
          member_now_working_in_flight: True,
          member_now_working_error: opt.None,
        )
      #(model, api.pause_me_active_task(MemberActiveTaskPaused))
    }
  }
}

/// Handle successful active task fetch response.
pub fn handle_fetched_ok(
  model: Model,
  payload: api.ActiveTaskPayload,
) -> #(Model, Effect(Msg)) {
  let api.ActiveTaskPayload(as_of: as_of, ..) = payload
  let server_ms = client_ffi.parse_iso_ms(as_of)
  let offset = client_ffi.now_ms() - server_ms

  Model(
    ..model,
    member_active_task: Loaded(payload),
    now_working_server_offset_ms: offset,
  )
  |> start_tick_if_needed
}

/// Handle failed active task fetch response.
pub fn handle_fetched_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> #(logout_model(model), effect.none())
    _ -> #(Model(..model, member_active_task: Failed(err)), effect.none())
  }
}

/// Handle successful start response.
pub fn handle_started_ok(
  model: Model,
  payload: api.ActiveTaskPayload,
) -> #(Model, Effect(Msg)) {
  let api.ActiveTaskPayload(as_of: as_of, ..) = payload
  let server_ms = client_ffi.parse_iso_ms(as_of)
  let offset = client_ffi.now_ms() - server_ms

  Model(
    ..model,
    member_now_working_in_flight: False,
    member_active_task: Loaded(payload),
    now_working_server_offset_ms: offset,
  )
  |> start_tick_if_needed
}

/// Handle failed start response.
pub fn handle_started_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  let model = Model(..model, member_now_working_in_flight: False)

  case err.status {
    401 -> #(logout_model(model), effect.none())
    _ -> #(
      Model(
        ..model,
        member_now_working_error: opt.Some(err.message),
        toast: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

/// Handle successful pause response.
pub fn handle_paused_ok(
  model: Model,
  payload: api.ActiveTaskPayload,
) -> #(Model, Effect(Msg)) {
  let api.ActiveTaskPayload(as_of: as_of, ..) = payload
  let server_ms = client_ffi.parse_iso_ms(as_of)
  let offset = client_ffi.now_ms() - server_ms

  let model =
    Model(
      ..model,
      member_now_working_in_flight: False,
      member_active_task: Loaded(payload),
      now_working_server_offset_ms: offset,
    )

  let model = case update_helpers.now_working_active_task(model) {
    opt.None -> Model(..model, now_working_tick_running: False)
    opt.Some(_) -> model
  }

  #(model, effect.none())
}

/// Handle failed pause response.
pub fn handle_paused_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  let model = Model(..model, member_now_working_in_flight: False)

  case err.status {
    401 -> #(logout_model(model), effect.none())
    _ -> #(
      Model(
        ..model,
        member_now_working_error: opt.Some(err.message),
        toast: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

/// Handle successful heartbeat response.
pub fn handle_heartbeated_ok(
  model: Model,
  payload: api.ActiveTaskPayload,
) -> #(Model, Effect(Msg)) {
  let api.ActiveTaskPayload(as_of: as_of, ..) = payload
  let server_ms = client_ffi.parse_iso_ms(as_of)
  let offset = client_ffi.now_ms() - server_ms

  Model(
    ..model,
    member_active_task: Loaded(payload),
    now_working_server_offset_ms: offset,
  )
  |> start_tick_if_needed
}

/// Handle failed heartbeat response.
pub fn handle_heartbeated_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> #(logout_model(model), effect.none())
    _ -> #(model, effect.none())
  }
}

/// Handle timer tick - updates tick counter and sends heartbeat every 60 ticks.
pub fn handle_ticked(model: Model) -> #(Model, Effect(Msg)) {
  let next_tick = model.now_working_tick + 1
  let model = Model(..model, now_working_tick: next_tick)

  let heartbeat_fx = case
    next_tick % 60 == 0
    && model.member_now_working_in_flight == False
    && update_helpers.now_working_active_task(model) != opt.None
  {
    True -> api.heartbeat_me_active_task(MemberActiveTaskHeartbeated)
    False -> effect.none()
  }

  case update_helpers.now_working_active_task(model) {
    opt.Some(_) -> #(model, effect.batch([tick_effect(), heartbeat_fx]))
    opt.None -> #(
      Model(..model, now_working_tick_running: False),
      effect.none(),
    )
  }
}

// =============================================================================
// Effects
// =============================================================================

/// Create effect that schedules the next tick in 1 second.
pub fn tick_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.set_timeout(1000, fn(_) { dispatch(NowWorkingTicked) })
    Nil
  })
}

/// Start tick timer if not already running and there's an active task.
pub fn start_tick_if_needed(model: Model) -> #(Model, Effect(Msg)) {
  case model.now_working_tick_running {
    True -> #(model, effect.none())

    False ->
      case update_helpers.now_working_active_task(model) {
        opt.Some(_) -> #(
          Model(..model, now_working_tick_running: True),
          tick_effect(),
        )
        opt.None -> #(model, effect.none())
      }
  }
}

// =============================================================================
// Helpers
// =============================================================================

/// Create model state for logout (401 response).
fn logout_model(model: Model) -> Model {
  Model(
    ..model,
    page: Login,
    user: opt.None,
    member_drag: opt.None,
    member_pool_drag_to_claim_armed: False,
    member_pool_drag_over_my_tasks: False,
  )
}
