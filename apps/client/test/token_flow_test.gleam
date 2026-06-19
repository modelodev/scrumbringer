import gleam/option

import domain/api_error.{type ApiError, ApiError}
import scrumbringer_client/token_flow

pub fn init_with_missing_token_stays_no_token_state_test() {
  let #(model, action) = token_flow.init("")

  let assert token_flow.Model(token: "", state: token_flow.NoToken, ..) = model
  let assert token_flow.NoOp = action
}

pub fn init_with_token_triggers_validation_test() {
  let #(model, action) = token_flow.init("token")

  let assert token_flow.Model(token: "token", state: token_flow.Validating, ..) =
    model
  let assert token_flow.ValidateToken("token") = action
}

pub fn token_validation_success_moves_to_ready_test() {
  let #(model, _) = token_flow.init("token")

  let #(next, action) =
    token_flow.update(
      model,
      token_flow.TokenValidated(Ok("person@example.com")),
      default_error_state,
    )

  let assert token_flow.Model(state: token_flow.Ready("person@example.com"), ..) =
    next
  let assert token_flow.NoOp = action
}

pub fn token_validation_failure_moves_to_invalid_test() {
  let #(model, _) = token_flow.init("token")

  let err = ApiError(status: 403, code: "TOKEN_INVALID", message: "Nope")

  let #(next, action) =
    token_flow.update(
      model,
      token_flow.TokenValidated(Error(err)),
      default_error_state,
    )

  let assert token_flow.Model(
    state: token_flow.Invalid(code: "TOKEN_INVALID", message: "Nope"),
    ..,
  ) = next
  let assert token_flow.NoOp = action
}

pub fn submit_requires_min_password_length_test() {
  let #(model, _) = token_flow.init("token")

  let #(model, _) =
    token_flow.update(
      model,
      token_flow.TokenValidated(Ok("person@example.com")),
      default_error_state,
    )

  let #(model, _) =
    token_flow.update(
      model,
      token_flow.PasswordChanged("short"),
      default_error_state,
    )

  let #(next, action) =
    token_flow.update(model, token_flow.Submitted, default_error_state)

  let assert token_flow.Model(
    password_error: option.Some("Password must be at least 12 characters"),
    ..,
  ) = next
  let assert token_flow.NoOp = action
}

pub fn submit_with_valid_password_triggers_submit_action_test() {
  let #(model, _) = token_flow.init("token")

  let #(model, _) =
    token_flow.update(
      model,
      token_flow.TokenValidated(Ok("person@example.com")),
      default_error_state,
    )

  let #(model, _) =
    token_flow.update(
      model,
      token_flow.PasswordChanged("passwordpassword"),
      default_error_state,
    )

  let #(next, action) =
    token_flow.update(model, token_flow.Submitted, default_error_state)

  let assert token_flow.Model(
    state: token_flow.Submitting("person@example.com"),
    ..,
  ) = next
  let assert token_flow.Submit(token: "token", password: "passwordpassword") =
    action
}

pub fn completed_success_moves_to_done_and_emits_action_test() {
  let #(model, _) = token_flow.init("token")

  let #(next, action) =
    token_flow.update(model, token_flow.Finished(Ok(7)), default_error_state)

  let assert token_flow.Model(state: token_flow.Done, ..) = next
  let assert token_flow.Succeeded(7) = action
}

pub fn completed_error_uses_handler_and_sets_submit_error_test() {
  let #(model, _) = token_flow.init("token")

  let #(model, _) =
    token_flow.update(
      model,
      token_flow.TokenValidated(Ok("person@example.com")),
      default_error_state,
    )

  let #(model, _) =
    token_flow.update(
      model,
      token_flow.PasswordChanged("passwordpassword"),
      default_error_state,
    )

  let #(model, _) =
    token_flow.update(model, token_flow.Submitted, default_error_state)

  let err = ApiError(status: 403, code: "SUBMIT_FAILED", message: "Nope")

  let #(next, action) =
    token_flow.update(model, token_flow.Finished(Error(err)), error_to_invalid)

  let assert token_flow.Model(
    state: token_flow.Invalid(code: "SUBMIT_FAILED", message: "Nope"),
    submit_error: option.Some("Nope"),
    ..,
  ) = next
  let assert token_flow.NoOp = action
}

fn default_error_state(email: String, _err: ApiError) -> token_flow.State {
  token_flow.Ready(email)
}

fn error_to_invalid(_email: String, err: ApiError) -> token_flow.State {
  token_flow.Invalid(code: err.code, message: err.message)
}
