//// Member task notes state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/activity/entity as activity_entity
import domain/note/entity.{type Note}
import domain/remote.{type Remote, NotAsked}
import scrumbringer_client/client_state/dialog_mode

/// Represents member notes state.
pub type Model {
  Model(
    member_hover_notes_cache: Dict(Int, List(Note)),
    member_hover_notes_pending: Dict(Int, Bool),
    member_notes_task_id: Option(Int),
    member_notes: Remote(List(Note)),
    member_note_content: String,
    member_note_in_flight: Bool,
    member_note_error: Option(String),
    member_note_dialog_mode: dialog_mode.DialogMode,
    member_note_delete_in_flight: Option(Int),
    member_note_pin_in_flight: Option(Int),
    member_activity: Remote(List(activity_entity.ActivityEvent)),
    member_activity_total: Int,
    member_activity_loading_more: Bool,
  )
}

/// Provides default member notes state.
pub fn default_model() -> Model {
  Model(
    member_hover_notes_cache: dict.new(),
    member_hover_notes_pending: dict.new(),
    member_notes_task_id: option.None,
    member_notes: NotAsked,
    member_note_content: "",
    member_note_in_flight: False,
    member_note_error: option.None,
    member_note_dialog_mode: dialog_mode.DialogClosed,
    member_note_delete_in_flight: option.None,
    member_note_pin_in_flight: option.None,
    member_activity: NotAsked,
    member_activity_total: 0,
    member_activity_loading_more: False,
  )
}
