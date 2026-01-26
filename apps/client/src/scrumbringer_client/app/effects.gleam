//// Application-level effects for Scrumbringer client.
////
//// ## Mission
////
//// Centralizes shared effect creators used across features for navigation,
//// persistence, and browser interactions.
////
//// ## Responsibilities
////
//// - Navigation effects (URL push/replace wrappers)
//// - localStorage persistence effects (theme, pool preferences)
//// - Focus/blur effects for form elements
//// - Page title updates
////
//// ## Non-responsibilities
////
//// - Feature-specific effects (see features/*/update.gleam)
//// - View rendering (see features/*/view.gleam)
//// - State types (see client_state.gleam)
//// - Route parsing/formatting (see router.gleam)
////
//// ## Relations
////
//// - **router.gleam**: Low-level navigation and URL formatting
//// - **theme.gleam**: Theme persistence (uses local_storage_set)
//// - **pool_prefs.gleam**: Pool preferences serialization
//// - **client_ffi.gleam**: Browser FFI functions

import lustre/effect.{type Effect}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/pool_prefs
import scrumbringer_client/router
import scrumbringer_client/theme.{type Theme}

// =============================================================================
// Navigation Effects
// =============================================================================

/// Push a new URL to browser history (creates back button entry).
///
/// Wrapper around router.push for convenience.
pub fn navigate_push(route: router.Route) -> Effect(msg) {
  router.push(route)
}

/// Replace current URL in browser history (no back button entry).
///
/// Wrapper around router.replace for convenience.
pub fn navigate_replace(route: router.Route) -> Effect(msg) {
  router.replace(route)
}

/// Update the browser document title for the current route.
///
/// Sets title in format "Section - Scrumbringer" for authenticated pages.
pub fn update_title(
  route: router.Route,
  locale: i18n_locale.Locale,
) -> Effect(msg) {
  router.update_page_title(route, locale)
}

// =============================================================================
// Theme Persistence Effects
// =============================================================================

/// Save theme preference to localStorage.
///
/// Persists the user's theme choice for future sessions.
pub fn save_theme(t: Theme) -> Effect(msg) {
  effect.from(fn(_dispatch) { theme.save_to_storage(t) })
}

// =============================================================================
// Pool Preferences Persistence Effects
// =============================================================================

/// Save pool filters visibility preference to localStorage.
pub fn save_pool_filters_visible(visible: Bool) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.filters_visible_storage_key,
      pool_prefs.encode_filters_visibility(pool_prefs.visibility_from_bool(
        visible,
      )),
    )
  })
}

/// Save pool view mode preference to localStorage.
pub fn save_pool_view_mode(mode: pool_prefs.ViewMode) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.view_mode_storage_key,
      pool_prefs.encode_view_mode_storage(mode),
    )
  })
}

// =============================================================================
// Focus Effects
// =============================================================================

/// Focus an element by its ID.
///
/// Useful for focusing form inputs after dialog opens.
pub fn focus_element(element_id: String) -> Effect(msg) {
  effect.from(fn(_dispatch) { client_ffi.focus_element(element_id) })
}

/// Focus an element after a timeout (in milliseconds).
///
/// Useful for focusing inputs after dialogs render.
pub fn focus_element_after_timeout(element_id: String, ms: Int) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    client_ffi.set_timeout(ms, fn(_) {
      client_ffi.focus_element(element_id)
      Nil
    })
    Nil
  })
}

// =============================================================================
// Timer Effects
// =============================================================================

/// Schedule a message after a timeout.
///
/// Useful for tickers and delayed UI updates.
pub fn schedule_timeout(ms: Int, make_msg: fn() -> msg) -> Effect(msg) {
  effect.from(fn(dispatch) {
    client_ffi.set_timeout(ms, fn(_) { dispatch(make_msg()) })
    Nil
  })
}

// =============================================================================
// Sidebar Preferences Persistence Effects
// =============================================================================

/// localStorage key for sidebar collapse state
const sidebar_storage_key = "scrumbringer:sidebar-collapsed"

/// Save sidebar collapse state to localStorage.
///
/// Persists both config and org section collapsed states as "config,org" format.
pub fn save_sidebar_state(state: client_state.SidebarCollapse) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    let value = case state {
      client_state.NoneCollapsed -> "0,0"
      client_state.ConfigCollapsed -> "1,0"
      client_state.OrgCollapsed -> "0,1"
      client_state.BothCollapsed -> "1,1"
    }
    theme.local_storage_set(sidebar_storage_key, value)
  })
}

/// Load sidebar collapse state from localStorage.
///
/// Returns the persisted SidebarCollapse value.
/// Defaults to NoneCollapsed if not found or invalid.
pub fn load_sidebar_state() -> client_state.SidebarCollapse {
  case theme.local_storage_get(sidebar_storage_key) {
    "" -> client_state.NoneCollapsed
    val -> {
      case val {
        "1,1" -> client_state.BothCollapsed
        "1,0" -> client_state.ConfigCollapsed
        "0,1" -> client_state.OrgCollapsed
        _ -> client_state.NoneCollapsed
      }
    }
  }
}
