import gleam/option
import gleeunit/should

import domain/api_error.{type ApiError, ApiError}
import scrumbringer_client/token_flow

pub fn init_with_missing_token_stays_no_token_state_test() {
  let #(model, action) = token_flow.init("")

  let token_flow.Model(token: token, state: state, ..) = model

  token |> should.equal("")
  state |> should.equal(token_flow.NoToken)
  action |> should.equal(token_flow.NoOp)
}

pub fn init_with_token_triggers_validation_test() {
  let #(model, action) = token_flow.init("token")

  let token_flow.Model(token: token, state: state, ..) = model

  token |> should.equal("token")
  state |> should.equal(token_flow.Validating)
  action |> should.equal(token_flow.ValidateToken("token"))
}

pub fn token_validation_success_moves_to_ready_test() {
  let #(model, _) = token_flow.init("token")

  let #(next, action) =
    token_flow.update(
      model,
      token_flow.TokenValidated(Ok("person@example.com")),
      default_error_state,
    )

  let token_flow.Model(state: state, ..) = next

  state |> should.equal(token_flow.Ready("person@example.com"))
  action |> should.equal(token_flow.NoOp)
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

  let token_flow.Model(state: state, ..) = next

  state
  |> should.equal(token_flow.Invalid(code: "TOKEN_INVALID", message: "Nope"))
  action |> should.equal(token_flow.NoOp)
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

  let token_flow.Model(password_error: password_error, ..) = next

  password_error
  |> should.equal(option.Some("Password must be at least 12 characters"))
  action |> should.equal(token_flow.NoOp)
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

  let token_flow.Model(state: state, ..) = next

  state |> should.equal(token_flow.Submitting("person@example.com"))
  action
  |> should.equal(token_flow.Submit(
    token: "token",
    password: "passwordpassword",
  ))
}

pub fn completed_success_moves_to_done_and_emits_action_test() {
  let #(model, _) = token_flow.init("token")

  let #(next, action) =
    token_flow.update(model, token_flow.Completed(Ok(7)), default_error_state)

  let token_flow.Model(state: state, ..) = next

  state |> should.equal(token_flow.Done)
  action |> should.equal(token_flow.Succeeded(7))
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
    token_flow.update(model, token_flow.Completed(Error(err)), error_to_invalid)

  let token_flow.Model(state: state, submit_error: submit_error, ..) = next

  state
  |> should.equal(token_flow.Invalid(code: "SUBMIT_FAILED", message: "Nope"))
  submit_error |> should.equal(option.Some("Nope"))
  action |> should.equal(token_flow.NoOp)
}

fn default_error_state(email: String, _err: ApiError) -> token_flow.State {
  token_flow.Ready(email)
}

fn error_to_invalid(_email: String, err: ApiError) -> token_flow.State {
  token_flow.Invalid(code: err.code, message: err.message)
}
