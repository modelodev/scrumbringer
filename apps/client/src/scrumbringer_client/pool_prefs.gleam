import gleam/string

pub const filters_visible_storage_key = "sb_pool_filters_visible"

pub const view_mode_storage_key = "sb_pool_view_mode"

pub type ViewMode {
  Canvas
  List
}

pub fn serialize_view_mode(mode: ViewMode) -> String {
  case mode {
    Canvas -> "canvas"
    List -> "list"
  }
}

pub fn deserialize_view_mode(value: String) -> ViewMode {
  case string.trim(value) {
    "list" -> List
    "canvas" -> Canvas
    _ -> Canvas
  }
}

pub fn serialize_bool(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

pub fn deserialize_bool(value: String, default: Bool) -> Bool {
  case string.trim(value) {
    "true" -> True
    "false" -> False
    _ -> default
  }
}

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

pub type ShortcutAction {
  NoAction
  ToggleFilters
  FocusSearch
  OpenCreate
}

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
