//// Auth-related helper wrappers.

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/features/auth/helpers as auth_helpers

/// Clear all drag-related state from the model.
pub const clear_drag_state = auth_helpers.clear_drag_state

/// Reset model to login page, clearing user and drag state.
pub const reset_to_login = auth_helpers.reset_to_login

/// Handle common API auth errors (401/403).
pub const handle_auth_error = auth_helpers.handle_auth_error

/// Handle 401 errors with redirect to login, or run fallback for other errors.
pub fn handle_401_or(
  model: Model,
  err: ApiError,
  fallback: fn() -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> reset_to_login(model)
    _ -> fallback()
  }
}
