import gleam/option.{None, Some}
import lustre/effect

import domain/org_role
import domain/user
import scrumbringer_client/client_state
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/client_update
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/features/auth/update as auth_update

fn context() -> auth_update.Context(Nil) {
  auth_update.Context(
    on_login_dom_values_read: fn(_email, _password) { Nil },
    on_login_finished: fn(_result) { Nil },
    on_forgot_password_finished: fn(_result) { Nil },
    on_forgot_password_copy_finished: fn(_ok) { Nil },
    on_logout_finished: fn(_result) { Nil },
    on_accept_invite: fn(_inner) { Nil },
    on_reset_password: fn(_inner) { Nil },
    email_and_password_required: "Email and password required",
    email_required: "Email required",
    invalid_credentials: "Invalid credentials",
    copying: "Copying",
    copied: "Copied",
    copy_failed: "Copy failed",
  )
}

fn admin_user() -> user.User {
  user.User(
    id: 1,
    email: "admin@example.com",
    org_id: 1,
    org_role: org_role.Admin,
    created_at: "2026-01-01T00:00:00Z",
  )
}

pub fn login_submitted_ignores_when_in_flight_test() {
  let model =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      login_in_flight: True,
      login_error: Some("err"),
    )

  let #(next, fx, action) =
    auth_update.update(model, auth_messages.LoginSubmitted, context())

  let assert True = next.login_in_flight
  let assert Some("err") = next.login_error
  let assert True = fx == effect.none()
  let assert auth_update.NoAction = action
}

pub fn login_submitted_sets_in_flight_and_clears_error_test() {
  let model =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      login_in_flight: False,
      login_error: Some("err"),
    )

  let #(next, _fx, action) =
    auth_update.update(model, auth_messages.LoginSubmitted, context())

  let assert True = next.login_in_flight
  let assert None = next.login_error
  let assert auth_update.NoAction = action
}

pub fn login_finished_ok_resets_local_auth_and_emits_action_test() {
  let model =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      login_in_flight: True,
      login_password: "secret",
    )

  let #(next, fx, action) =
    auth_update.update(
      model,
      auth_messages.LoginFinished(Ok(admin_user())),
      context(),
    )

  let assert False = next.login_in_flight
  let assert "" = next.login_password
  let assert True = fx == effect.none()
  let assert auth_update.LoginSucceeded(user) = action
  let assert "admin@example.com" = user.email
}

pub fn client_update_login_finished_admin_lands_on_member_page_test() {
  let #(next, _fx) =
    client_update.update(
      client_state.default_model(),
      client_state.auth_msg(auth_messages.LoginFinished(Ok(admin_user()))),
    )

  let assert client_state.Member = next.core.page
  let assert Some(user) = next.core.user
  let assert "admin@example.com" = user.email
}
