import gleam/option
import gleeunit/should

import scrumbringer_client/accept_invite
import scrumbringer_client/api
import scrumbringer_domain/org_role
import scrumbringer_domain/user

pub fn init_with_missing_token_stays_in_no_token_state_test() {
  let #(model, action) = accept_invite.init("")

  let accept_invite.Model(token: token, state: state, ..) = model

  token |> should.equal("")
  state |> should.equal(accept_invite.NoToken)
  action |> should.equal(accept_invite.NoOp)
}

pub fn init_with_token_triggers_validation_test() {
  let #(model, action) = accept_invite.init("il_token")

  let accept_invite.Model(token: token, state: state, ..) = model

  token |> should.equal("il_token")
  state |> should.equal(accept_invite.Validating)
  action |> should.equal(accept_invite.ValidateToken("il_token"))
}

pub fn token_validation_success_moves_to_ready_test() {
  let #(model, _) = accept_invite.init("il_token")

  let #(next, action) =
    accept_invite.update(
      model,
      accept_invite.TokenValidated(Ok("member@example.com")),
    )

  let accept_invite.Model(state: state, ..) = next

  state |> should.equal(accept_invite.Ready("member@example.com"))
  action |> should.equal(accept_invite.NoOp)
}

pub fn token_validation_failure_moves_to_invalid_test() {
  let #(model, _) = accept_invite.init("il_token")

  let err = api.ApiError(status: 403, code: "INVITE_INVALID", message: "Nope")

  let #(next, action) =
    accept_invite.update(model, accept_invite.TokenValidated(Error(err)))

  let accept_invite.Model(state: state, ..) = next

  state
  |> should.equal(accept_invite.Invalid(code: "INVITE_INVALID", message: "Nope"))
  action |> should.equal(accept_invite.NoOp)
}

pub fn submit_requires_min_password_length_test() {
  let #(model, _) = accept_invite.init("il_token")

  let #(model, _) =
    accept_invite.update(
      model,
      accept_invite.TokenValidated(Ok("member@example.com")),
    )

  let #(model, _) =
    accept_invite.update(model, accept_invite.PasswordChanged("short"))

  let #(next, action) = accept_invite.update(model, accept_invite.Submitted)

  let accept_invite.Model(password_error: password_error, ..) = next

  password_error
  |> should.equal(option.Some("Password must be at least 12 characters"))
  action |> should.equal(accept_invite.NoOp)
}

pub fn submit_with_valid_password_triggers_register_action_test() {
  let #(model, _) = accept_invite.init("il_token")

  let #(model, _) =
    accept_invite.update(
      model,
      accept_invite.TokenValidated(Ok("member@example.com")),
    )

  let #(model, _) =
    accept_invite.update(
      model,
      accept_invite.PasswordChanged("passwordpassword"),
    )

  let #(next, action) = accept_invite.update(model, accept_invite.Submitted)

  let accept_invite.Model(state: state, ..) = next

  state |> should.equal(accept_invite.Registering("member@example.com"))
  action
  |> should.equal(accept_invite.Register(
    token: "il_token",
    password: "passwordpassword",
  ))
}

pub fn registration_success_emits_authed_action_test() {
  let #(model, _) = accept_invite.init("il_token")

  let #(model, _) =
    accept_invite.update(
      model,
      accept_invite.TokenValidated(Ok("member@example.com")),
    )

  let #(model, _) =
    accept_invite.update(
      model,
      accept_invite.PasswordChanged("passwordpassword"),
    )

  let #(model, _) = accept_invite.update(model, accept_invite.Submitted)

  let authed_user =
    user.User(
      id: 2,
      email: "member@example.com",
      org_id: 1,
      org_role: org_role.Member,
      created_at: "2026-01-14T00:00:00Z",
    )

  let #(next, action) =
    accept_invite.update(model, accept_invite.Registered(Ok(authed_user)))

  let accept_invite.Model(state: state, ..) = next

  state |> should.equal(accept_invite.Done)
  action |> should.equal(accept_invite.Authed(authed_user))
}
