//// Typed localStorage accessors for client preferences.
////
//// Centralizes key-specific decoding/encoding to avoid raw string usage.

import gleam/option

import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/pool_prefs
import scrumbringer_client/theme

/// localStorage key for sidebar collapse state.
const sidebar_storage_key = "scrumbringer:sidebar-collapsed"

pub type SidebarStateStorage {
  SidebarStateStored(ui_state.SidebarCollapse)
  SidebarStateInvalid(String)
}

pub fn load_pool_filters_visibility(
  default_visible: Bool,
) -> pool_prefs.FiltersVisibility {
  theme.local_storage_get(pool_prefs.filters_visible_storage_key)
  |> pool_prefs.decode_filters_visibility
  |> filters_visibility_or_default(default_visible)
}

fn filters_visibility_or_default(
  value: option.Option(pool_prefs.FiltersVisibility),
  default_visible: Bool,
) -> pool_prefs.FiltersVisibility {
  case value {
    option.None -> pool_prefs.visibility_from_bool(default_visible)
    option.Some(visibility) -> visibility
  }
}

pub fn save_pool_filters_visibility(value: pool_prefs.FiltersVisibility) -> Nil {
  theme.local_storage_set(
    pool_prefs.filters_visible_storage_key,
    pool_prefs.encode_filters_visibility(value),
  )
}

pub fn load_pool_view_mode() -> pool_prefs.ViewMode {
  case
    pool_prefs.decode_view_mode_storage(theme.local_storage_get(
      pool_prefs.view_mode_storage_key,
    ))
  {
    pool_prefs.ViewModeStored(mode) -> mode
    pool_prefs.ViewModeInvalid(_) -> pool_prefs.Canvas
  }
}

pub fn save_pool_view_mode(mode: pool_prefs.ViewMode) -> Nil {
  theme.local_storage_set(
    pool_prefs.view_mode_storage_key,
    pool_prefs.encode_view_mode_storage(mode),
  )
}

pub fn decode_sidebar_state_storage(value: String) -> SidebarStateStorage {
  case value {
    "1,1" -> SidebarStateStored(ui_state.BothCollapsed)
    "1,0" -> SidebarStateStored(ui_state.ConfigCollapsed)
    "0,1" -> SidebarStateStored(ui_state.OrgCollapsed)
    "0,0" -> SidebarStateStored(ui_state.NoneCollapsed)
    other -> SidebarStateInvalid(other)
  }
}

pub fn encode_sidebar_state_storage(state: ui_state.SidebarCollapse) -> String {
  case state {
    ui_state.NoneCollapsed -> "0,0"
    ui_state.ConfigCollapsed -> "1,0"
    ui_state.OrgCollapsed -> "0,1"
    ui_state.BothCollapsed -> "1,1"
  }
}

// Default: BothCollapsed - Config and Org sections start collapsed
pub fn load_sidebar_state() -> ui_state.SidebarCollapse {
  case theme.local_storage_get(sidebar_storage_key) {
    "" -> ui_state.BothCollapsed
    val ->
      case decode_sidebar_state_storage(val) {
        SidebarStateStored(state) -> state
        SidebarStateInvalid(_) -> ui_state.BothCollapsed
      }
  }
}

pub fn save_sidebar_state(state: ui_state.SidebarCollapse) -> Nil {
  theme.local_storage_set(
    sidebar_storage_key,
    encode_sidebar_state_storage(state),
  )
}
