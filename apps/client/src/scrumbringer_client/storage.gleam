//// Typed localStorage accessors for client preferences.
////
//// Centralizes key-specific decoding/encoding to avoid raw string usage.

import gleam/option

import scrumbringer_client/client_state
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/pool_prefs
import scrumbringer_client/theme

/// localStorage key for sidebar collapse state.
const sidebar_storage_key = "scrumbringer:sidebar-collapsed"

pub fn load_theme() -> theme.Theme {
  theme.load_from_storage()
}

pub fn save_theme(theme_value: theme.Theme) -> Nil {
  theme.save_to_storage(theme_value)
}

pub fn load_locale() -> i18n_locale.Locale {
  i18n_locale.load()
}

pub fn save_locale(locale: i18n_locale.Locale) -> Nil {
  i18n_locale.save(locale)
}

pub fn load_pool_filters_visibility(
  default_visible: Bool,
) -> pool_prefs.FiltersVisibility {
  theme.local_storage_get(pool_prefs.filters_visible_storage_key)
  |> pool_prefs.decode_filters_visibility
  |> option.unwrap(pool_prefs.visibility_from_bool(default_visible))
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

// Justification: nested case improves clarity for branching logic.
// Default: BothCollapsed - Config and Org sections start collapsed
pub fn load_sidebar_state() -> client_state.SidebarCollapse {
  case theme.local_storage_get(sidebar_storage_key) {
    "" -> ui_state.BothCollapsed
    val ->
      case val {
        "1,1" -> ui_state.BothCollapsed
        "1,0" -> ui_state.ConfigCollapsed
        "0,1" -> ui_state.OrgCollapsed
        _ -> ui_state.BothCollapsed
      }
  }
}

pub fn save_sidebar_state(state: client_state.SidebarCollapse) -> Nil {
  let value = case state {
    ui_state.NoneCollapsed -> "0,0"
    ui_state.ConfigCollapsed -> "1,0"
    ui_state.OrgCollapsed -> "0,1"
    ui_state.BothCollapsed -> "1,1"
  }

  theme.local_storage_set(sidebar_storage_key, value)
}
