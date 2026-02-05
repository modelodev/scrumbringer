//// Member task positions state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

/// Represents member positions state.
pub type Model {
  Model(
    member_positions_by_task: Dict(Int, #(Int, Int)),
    member_canvas_left: Int,
    member_canvas_top: Int,
    member_position_edit_task: Option(Int),
    member_position_edit_x: String,
    member_position_edit_y: String,
    member_position_edit_in_flight: Bool,
    member_position_edit_error: Option(String),
  )
}

/// Provides default member positions state.
pub fn default_model() -> Model {
  Model(
    member_positions_by_task: dict.new(),
    member_canvas_left: 0,
    member_canvas_top: 0,
    member_position_edit_task: option.None,
    member_position_edit_x: "",
    member_position_edit_y: "",
    member_position_edit_in_flight: False,
    member_position_edit_error: option.None,
  )
}
