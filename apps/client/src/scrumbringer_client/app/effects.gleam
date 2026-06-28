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
import scrumbringer_client/client_state.{
  type Msg, ToastShow, ToastShowWithAction,
}
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/pool_prefs
import scrumbringer_client/storage
import scrumbringer_client/ui/toast

// =============================================================================
// Pool Preferences Persistence Effects
// =============================================================================

/// Save pool view mode preference to localStorage.
pub fn save_pool_view_mode(mode: pool_prefs.ViewMode) -> Effect(msg) {
  effect.from(fn(_dispatch) { storage.save_pool_view_mode(mode) })
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
// Toast Effects
// =============================================================================

/// Build a toast effect to show a message with a variant.
pub fn toast_effect(message: String, variant: toast.ToastVariant) -> Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(ToastShow(message, variant)) })
}

/// Build a toast effect with an action button.
pub fn toast_effect_with_action(
  message: String,
  variant: toast.ToastVariant,
  action: toast.ToastAction,
) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    dispatch(ToastShowWithAction(message, variant, action))
  })
}

/// Build a success toast effect.
pub fn toast_success(message: String) -> Effect(Msg) {
  toast_effect(message, toast.Success)
}

/// Build an error toast effect.
pub fn toast_error(message: String) -> Effect(Msg) {
  toast_effect(message, toast.Error)
}

/// Build a warning toast effect.
pub fn toast_warning(message: String) -> Effect(Msg) {
  toast_effect(message, toast.Warning)
}

// =============================================================================
// Sidebar Preferences Persistence Effects
// =============================================================================

/// Save sidebar collapse state to localStorage.
///
/// Persists both config and org section collapsed states as "config,org" format.
pub fn save_sidebar_state(state: ui_state.SidebarCollapse) -> Effect(msg) {
  effect.from(fn(_dispatch) { storage.save_sidebar_state(state) })
}

/// Load sidebar collapse state from localStorage.
///
/// Returns the persisted SidebarCollapse value.
/// Defaults to NoneCollapsed if not found or invalid.
pub fn load_sidebar_state() -> ui_state.SidebarCollapse {
  storage.load_sidebar_state()
}
