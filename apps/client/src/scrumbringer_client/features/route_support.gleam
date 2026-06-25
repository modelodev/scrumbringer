//// Shared helpers for root feature route adapters.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/features/auth/helpers as auth_helpers

pub fn apply_auth_check_before(
  model: client_state.Model,
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_error {
    opt.None -> apply_update()
    opt.Some(err) -> auth_helpers.handle_401_or(model, err, apply_update)
  }
}

pub fn apply_auth_check_after(
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_error {
    opt.None -> apply_update()
    opt.Some(err) -> {
      let #(next, fx) = apply_update()
      auth_helpers.handle_401_or(next, err, fn() { #(next, fx) })
    }
  }
}
