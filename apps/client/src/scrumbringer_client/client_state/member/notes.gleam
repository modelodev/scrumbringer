//// Member task notes state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/task.{type TaskNote}
import scrumbringer_client/client_state/dialog_mode

/// Represents member notes state.
pub type Model {
  Model(
    member_hover_notes_cache: Dict(Int, List(TaskNote)),
    member_hover_notes_pending: Dict(Int, Bool),
    member_notes_task_id: Option(Int),
    member_notes: Remote(List(TaskNote)),
    member_note_content: String,
    member_note_in_flight: Bool,
    member_note_error: Option(String),
    member_note_dialog_mode: dialog_mode.DialogMode,
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
  )
}
