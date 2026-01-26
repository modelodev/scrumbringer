//// Task pool user preferences and keyboard shortcuts.
////
//// Manages view mode (canvas/list), filter visibility persistence,
//// and keyboard shortcut handling for the task pool interface.

import gleam/option
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

/// Stored view mode decoding result.
pub type ViewModeStorage {
  ViewModeStored(ViewMode)
  ViewModeInvalid(String)
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

/// Visibility state for pool filters.
pub type FiltersVisibility {
  FiltersVisible
  FiltersHidden
}

/// Provides visibility from bool.
///
/// Example:
///   visibility_from_bool(...)
pub fn visibility_from_bool(value: Bool) -> FiltersVisibility {
  case value {
    True -> FiltersVisible
    False -> FiltersHidden
  }
}

/// Provides visibility to bool.
///
/// Example:
///   visibility_to_bool(...)
pub fn visibility_to_bool(value: FiltersVisibility) -> Bool {
  case value {
    FiltersVisible -> True
    FiltersHidden -> False
  }
}

/// Encodes filters visibility for storage.
pub fn encode_filters_visibility(value: FiltersVisibility) -> String {
  case value {
    FiltersVisible -> "true"
    FiltersHidden -> "false"
  }
}

/// Decodes stored filters visibility with explicit invalid state.
pub fn decode_filters_visibility(
  value: String,
) -> option.Option(FiltersVisibility) {
  case string.trim(value) {
    "true" -> option.Some(FiltersVisible)
    "false" -> option.Some(FiltersHidden)
    _ -> option.None
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
  CloseDialog
}

/// Maps a key event to its corresponding shortcut action.
/// AC40: n (nueva tarea), f (filtros), / (búsqueda), Esc (cerrar)
pub fn shortcut_action(event: KeyEvent) -> ShortcutAction {
  let KeyEvent(
    key: key,
    ctrl: _ctrl,
    meta: _meta,
    shift: _shift,
    is_editing: editing,
    modal_open: modal_open,
  ) = event

  let key = string.lowercase(key)

  // Esc always works to close dialogs
  case key {
    "escape" -> CloseDialog
    _ -> shortcut_action_for_key(key, editing, modal_open)
  }
}

fn shortcut_action_for_key(
  key: String,
  editing: Bool,
  modal_open: Bool,
) -> ShortcutAction {
  case editing || modal_open {
    True -> NoAction
    False -> shortcut_action_for_unlocked_key(key)
  }
}

fn shortcut_action_for_unlocked_key(key: String) -> ShortcutAction {
  case key {
    "n" -> OpenCreate
    "f" -> ToggleFilters
    "/" -> FocusSearch
    _ -> NoAction
  }
}
