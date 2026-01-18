//// Task pool user preferences and keyboard shortcuts.
////
//// Manages view mode (canvas/list), filter visibility persistence,
//// and keyboard shortcut handling for the task pool interface.

import gleam/string

/// LocalStorage key for filter panel visibility.
pub const filters_visible_storage_key = "sb_pool_filters_visible"

/// LocalStorage key for view mode preference.
pub const view_mode_storage_key = "sb_pool_view_mode"

/// Task pool display mode.
pub type ViewMode {
  Canvas
  List
}

/// Converts a view mode to its string representation.
pub fn serialize_view_mode(mode: ViewMode) -> String {
  case mode {
    Canvas -> "canvas"
    List -> "list"
  }
}

/// Parses a string into a view mode (defaults to Canvas).
pub fn deserialize_view_mode(value: String) -> ViewMode {
  case string.trim(value) {
    "list" -> List
    "canvas" -> Canvas
    _ -> Canvas
  }
}

/// Converts a boolean to its string representation.
pub fn serialize_bool(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// Parses a string into a boolean with a default fallback.
pub fn deserialize_bool(value: String, default: Bool) -> Bool {
  case string.trim(value) {
    "true" -> True
    "false" -> False
    _ -> default
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
  ToggleFilters
  FocusSearch
  OpenCreate
}

/// Maps a key event to its corresponding shortcut action.
pub fn shortcut_action(event: KeyEvent) -> ShortcutAction {
  let KeyEvent(
    key: key,
    ctrl: ctrl,
    meta: meta,
    shift: shift,
    is_editing: editing,
    modal_open: modal_open,
  ) = event

  case editing || modal_open {
    True -> NoAction
    False -> {
      let cmd = ctrl || meta
      let key = string.lowercase(key)

      case cmd, shift, key {
        True, True, "f" -> ToggleFilters
        True, False, "k" -> FocusSearch
        False, False, "n" -> OpenCreate
        _, _, _ -> NoAction
      }
    }
  }
}
