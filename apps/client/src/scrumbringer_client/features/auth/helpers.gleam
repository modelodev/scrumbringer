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
import scrumbringer_client/client_state.{type Model, type Msg, Login, Model}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Drag State Management
// =============================================================================

/// Clear all drag-related state from the model.
///
/// Used when transitioning away from pages with drag functionality
/// (e.g., on logout or auth errors).
pub fn clear_drag_state(model: Model) -> Model {
  Model(
    ..model,
    member_drag: None,
    member_pool_drag_to_claim_armed: False,
    member_pool_drag_over_my_tasks: False,
  )
}

// =============================================================================
// Auth Error Handling
// =============================================================================

/// Reset model to login page, clearing user and drag state.
///
/// Used for 401 unauthorized responses across all handlers.
pub fn reset_to_login(model: Model) -> #(Model, Effect(Msg)) {
  #(clear_drag_state(Model(..model, page: Login, user: None)), effect.none())
}

/// Handle common API auth errors (401/403).
///
/// Returns Some with result for 401 (redirect to login) or 403 (toast).
/// Returns None for other errors that need custom handling.
pub fn handle_auth_error(
  model: Model,
  err: ApiError,
) -> Option(#(Model, Effect(Msg))) {
  case err.status {
    401 -> Some(reset_to_login(model))
    403 ->
      Some(#(
        Model(
          ..model,
          toast: Some(i18n.t(model.locale, i18n_text.NotPermitted)),
        ),
        effect.none(),
      ))
    _ -> None
  }
}
