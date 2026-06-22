//// Task pool user preferences and keyboard shortcuts.
////
//// Manages view mode (canvas/list) and keyboard shortcuts for the task pool
//// interface.

import gleam/string

/// LocalStorage key for view mode preference.
pub const view_mode_storage_key = "sb_pool_view_mode"

/// Task pool display mode.
pub type ViewMode {
  Canvas
  List
}

/// Stored view mode decoding result.
pub type ViewModeStorage {
  ViewModeStored(ViewMode)
  ViewModeInvalid(String)
}

/// Converts a view mode to its string representation.
fn serialize_view_mode(mode: ViewMode) -> String {
  case mode {
    Canvas -> "canvas"
    List -> "list"
  }
}

/// Encodes a view mode for storage.
pub fn encode_view_mode_storage(mode: ViewMode) -> String {
  serialize_view_mode(mode)
}

/// Decodes a stored view mode value with explicit invalid state.
pub fn decode_view_mode_storage(value: String) -> ViewModeStorage {
  case string.trim(value) {
    "list" -> ViewModeStored(List)
    "canvas" -> ViewModeStored(Canvas)
    other -> ViewModeInvalid(other)
  }
}

/// A keyboard event with modifier state.
pub type KeyEvent {
  KeyEvent(
    key: String,
    ctrl: Bool,
    meta: Bool,
    shift: Bool,
    is_editing: Bool,
    modal_open: Bool,
  )
}

/// Actions that can be triggered by keyboard shortcuts.
pub type ShortcutAction {
  NoAction
  FocusSearch
  OpenCreate
  CloseDialog
}

/// Maps a key event to its corresponding shortcut action.
/// AC40: n (nueva tarea), / (búsqueda), Esc (cerrar)
pub fn shortcut_action(event: KeyEvent) -> ShortcutAction {
  let KeyEvent(
    key: key,
    ctrl: ctrl,
    meta: meta,
    shift: shift,
    is_editing: editing,
    modal_open: modal_open,
  ) = event

  let key = string.lowercase(key)

  // Esc always works to close dialogs
  case key {
    "escape" -> CloseDialog
    _ -> shortcut_action_for_key(key, ctrl, meta, shift, editing, modal_open)
  }
}

fn shortcut_action_for_key(
  key: String,
  ctrl: Bool,
  meta: Bool,
  shift: Bool,
  editing: Bool,
  modal_open: Bool,
) -> ShortcutAction {
  case editing || modal_open || ctrl || meta || shift {
    True -> NoAction
    False -> shortcut_action_for_unlocked_key(key)
  }
}

fn shortcut_action_for_unlocked_key(key: String) -> ShortcutAction {
  case key {
    "n" -> OpenCreate
    "/" -> FocusSearch
    _ -> NoAction
  }
}
