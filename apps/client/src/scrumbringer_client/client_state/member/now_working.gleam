//// Now working member state.

import gleam/option.{type Option}

/// Represents now-working state for members.
pub type Model {
  Model(
    member_now_working_in_flight: Bool,
    member_now_working_error: Option(String),
    now_working_tick: Int,
    now_working_tick_running: Bool,
    now_working_server_offset_ms: Int,
  )
}

/// Provides default now-working state.
pub fn default_model() -> Model {
  Model(
    member_now_working_in_flight: False,
    member_now_working_error: option.None,
    now_working_tick: 0,
    now_working_tick_running: False,
    now_working_server_offset_ms: 0,
  )
}
