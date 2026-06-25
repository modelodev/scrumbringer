//// Shared helpers for root feature route adapters.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/features/auth/helpers as auth_helpers

pub type AuthCheck {
  NoAuthCheck
  CheckAuthBefore(ApiError)
  CheckAuthAfter(ApiError)
}

pub fn auth_check_before(auth_error: opt.Option(ApiError)) -> AuthCheck {
  case auth_error {
    opt.None -> NoAuthCheck
    opt.Some(err) -> CheckAuthBefore(err)
  }
}

pub fn auth_check_after(auth_error: opt.Option(ApiError)) -> AuthCheck {
  case auth_error {
    opt.None -> NoAuthCheck
    opt.Some(err) -> CheckAuthAfter(err)
  }
}

pub fn apply_auth_check(
  model: client_state.Model,
  auth_check: AuthCheck,
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_check {
    NoAuthCheck -> apply_update()
    CheckAuthBefore(err) ->
      apply_auth_check_before(model, opt.Some(err), apply_update)
    CheckAuthAfter(err) -> apply_auth_check_after(opt.Some(err), apply_update)
  }
}

fn apply_auth_check_before(
  model: client_state.Model,
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_error {
    opt.None -> apply_update()
    opt.Some(err) -> auth_helpers.handle_401_or(model, err, apply_update)
  }
}

fn apply_auth_check_after(
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
