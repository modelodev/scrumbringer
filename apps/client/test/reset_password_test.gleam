import gleam/option

import domain/api_error.{ApiError}
import scrumbringer_client/reset_password
import scrumbringer_client/token_flow

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

pub fn init_without_token_stays_no_token_test() {
  let #(model, action) = reset_password.init("")

  let token_flow.Model(state: state, token: token, ..) = model

  token |> assert_equal("")
  state |> assert_equal(token_flow.NoToken)
  action |> assert_equal(reset_password.NoOp)
}

pub fn init_with_token_triggers_validation_test() {
  let #(model, action) = reset_password.init("pr_token")

  let token_flow.Model(state: state, token: token, ..) = model

  token |> assert_equal("pr_token")
  state |> assert_equal(token_flow.Validating)
  action |> assert_equal(reset_password.ValidateToken("pr_token"))
}

pub fn token_validation_success_moves_to_ready_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(next, action) =
    reset_password.update(model, token_flow.TokenValidated(Ok("a@b.com")))

  let token_flow.Model(state: state, ..) = next

  state |> assert_equal(token_flow.Ready("a@b.com"))
  action |> assert_equal(reset_password.NoOp)
}

pub fn submit_requires_min_password_length_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, token_flow.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(model, token_flow.PasswordChanged("short"))

  let #(next, action) = reset_password.update(model, token_flow.Submitted)

  let token_flow.Model(password_error: password_error, ..) = next

  password_error
  |> assert_equal(option.Some("Password must be at least 12 characters"))
  action |> assert_equal(reset_password.NoOp)
}

pub fn submit_triggers_consume_action_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, token_flow.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(model, token_flow.PasswordChanged("passwordpassword"))

  let #(next, action) = reset_password.update(model, token_flow.Submitted)

  let token_flow.Model(state: state, ..) = next

  state |> assert_equal(token_flow.Submitting("a@b.com"))
  action
  |> assert_equal(reset_password.Consume(
    token: "pr_token",
    password: "passwordpassword",
  ))
}

pub fn consume_success_routes_to_login_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, token_flow.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(model, token_flow.PasswordChanged("passwordpassword"))

  let #(model, _) = reset_password.update(model, token_flow.Submitted)

  let #(next, action) =
    reset_password.update(model, token_flow.Completed(Ok(Nil)))

  let token_flow.Model(state: state, ..) = next

  state |> assert_equal(token_flow.Done)
  action |> assert_equal(reset_password.GoToLogin)
}

pub fn consume_failure_sets_invalid_state_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, token_flow.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(model, token_flow.PasswordChanged("passwordpassword"))

  let #(model, _) = reset_password.update(model, token_flow.Submitted)

  let err = ApiError(status: 403, code: "RESET_TOKEN_USED", message: "Used")

  let #(next, action) =
    reset_password.update(model, token_flow.Completed(Error(err)))

  let token_flow.Model(state: state, submit_error: submit_error, ..) = next

  state
  |> assert_equal(token_flow.Invalid(code: "RESET_TOKEN_USED", message: "Used"))
  submit_error |> assert_equal(option.Some("Used"))
  action |> assert_equal(reset_password.NoOp)
}
