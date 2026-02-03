//// Auth helper functions.
////
//// ## Mission
////
//// Provides auth-related state management functions for handling
//// authentication errors and state transitions.
////
//// ## Responsibilities
////
//// - Reset to login state on 401 errors
//// - Handle common auth errors (401/403)
//// - Clear drag state (needed on logout/auth transitions)
////
//// ## Relations
////
//// - **update_helpers.gleam**: Delegates to i18n_t for error messages
//// - **features/*/update.gleam**: All update modules use these for auth errors
//// - **client_state.gleam**: Uses Model, Msg, Login page

import gleam/option.{type Option, None, Some}

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state as client_state_module
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/toast

// =============================================================================
// Drag State Management
// =============================================================================

/// Clear all drag-related state from the model.
///
/// Used when transitioning away from pages with drag functionality
/// (e.g., on logout or auth errors).
pub fn clear_drag_state(
  model: client_state_module.Model,
) -> client_state_module.Model {
  client_state_module.update_member(model, fn(member) {
    member_state.reset_drag_state(member)
  })
}

// =============================================================================
// Auth Error Handling
// =============================================================================

/// Reset model to login page, clearing user and drag state.
///
/// Used for 401 unauthorized responses across all handlers.
pub fn reset_to_login(
  model: client_state_module.Model,
) -> #(client_state_module.Model, Effect(client_state_module.Msg)) {
  let model =
    client_state_module.update_core(model, fn(core) {
      client_state_module.CoreModel(
        ..core,
        page: client_state_module.Login,
        user: None,
      )
    })
  #(clear_drag_state(model), effect.none())
}

/// Handle common API auth errors (401/403).
///
/// Returns Some with result for 401 (redirect to login) or 403 (toast).
/// Returns None for other errors that need custom handling.
pub fn handle_auth_error(
  model: client_state_module.Model,
  err: ApiError,
) -> Option(#(client_state_module.Model, Effect(client_state_module.Msg))) {
  case err.status {
    401 -> Some(reset_to_login(model))
    403 ->
      Some(#(
        model,
        effect.from(fn(dispatch) {
          dispatch(client_state_module.ToastShow(
            i18n.t(model.ui.locale, i18n_text.NotPermitted),
            toast.Warning,
          ))
        }),
      ))
    _ -> None
  }
}
