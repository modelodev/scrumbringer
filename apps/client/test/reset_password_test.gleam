import gleam/option
import gleeunit/should

import scrumbringer_client/api
import scrumbringer_client/reset_password

pub fn init_without_token_stays_no_token_test() {
  let #(model, action) = reset_password.init("")

  let reset_password.Model(state: state, token: token, ..) = model

  token |> should.equal("")
  state |> should.equal(reset_password.NoToken)
  action |> should.equal(reset_password.NoOp)
}

pub fn init_with_token_triggers_validation_test() {
  let #(model, action) = reset_password.init("pr_token")

  let reset_password.Model(state: state, token: token, ..) = model

  token |> should.equal("pr_token")
  state |> should.equal(reset_password.Validating)
  action |> should.equal(reset_password.ValidateToken("pr_token"))
}

pub fn token_validation_success_moves_to_ready_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(next, action) =
    reset_password.update(model, reset_password.TokenValidated(Ok("a@b.com")))

  let reset_password.Model(state: state, ..) = next

  state |> should.equal(reset_password.Ready("a@b.com"))
  action |> should.equal(reset_password.NoOp)
}

pub fn submit_requires_min_password_length_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, reset_password.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(model, reset_password.PasswordChanged("short"))

  let #(next, action) = reset_password.update(model, reset_password.Submitted)

  let reset_password.Model(password_error: password_error, ..) = next

  password_error
  |> should.equal(option.Some("Password must be at least 12 characters"))
  action |> should.equal(reset_password.NoOp)
}

pub fn submit_triggers_consume_action_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, reset_password.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(
      model,
      reset_password.PasswordChanged("passwordpassword"),
    )

  let #(next, action) = reset_password.update(model, reset_password.Submitted)

  let reset_password.Model(state: state, ..) = next

  state |> should.equal(reset_password.Consuming("a@b.com"))
  action
  |> should.equal(reset_password.Consume(
    token: "pr_token",
    password: "passwordpassword",
  ))
}

pub fn consume_success_routes_to_login_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, reset_password.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(
      model,
      reset_password.PasswordChanged("passwordpassword"),
    )

  let #(model, _) = reset_password.update(model, reset_password.Submitted)

  let #(next, action) =
    reset_password.update(model, reset_password.Consumed(Ok(Nil)))

  let reset_password.Model(state: state, ..) = next

  state |> should.equal(reset_password.Done)
  action |> should.equal(reset_password.GoToLogin)
}

pub fn consume_failure_sets_invalid_state_test() {
  let #(model, _) = reset_password.init("pr_token")

  let #(model, _) =
    reset_password.update(model, reset_password.TokenValidated(Ok("a@b.com")))

  let #(model, _) =
    reset_password.update(
      model,
      reset_password.PasswordChanged("passwordpassword"),
    )

  let #(model, _) = reset_password.update(model, reset_password.Submitted)

  let err = api.ApiError(status: 403, code: "RESET_TOKEN_USED", message: "Used")

  let #(next, action) =
    reset_password.update(model, reset_password.Consumed(Error(err)))

  let reset_password.Model(state: state, submit_error: submit_error, ..) = next

  state
  |> should.equal(reset_password.Invalid(
    code: "RESET_TOKEN_USED",
    message: "Used",
  ))
  submit_error |> should.equal(option.Some("Used"))
  action |> should.equal(reset_password.NoOp)
}
