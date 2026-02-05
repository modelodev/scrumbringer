//// Auth-specific client state model.

import gleam/option.{type Option}

import scrumbringer_client/accept_invite
import scrumbringer_client/api/auth.{type PasswordReset}
import scrumbringer_client/reset_password

/// Represents AuthModel.
pub type AuthModel {
  AuthModel(
    login_email: String,
    login_password: String,
    login_error: Option(String),
    login_in_flight: Bool,
    forgot_password_open: Bool,
    forgot_password_email: String,
    forgot_password_in_flight: Bool,
    forgot_password_result: Option(PasswordReset),
    forgot_password_error: Option(String),
    forgot_password_copy_status: Option(String),
    accept_invite: accept_invite.Model,
    reset_password: reset_password.Model,
  )
}

/// Provides default auth model state.
pub fn default_model() -> AuthModel {
  AuthModel(
    login_email: "",
    login_password: "",
    login_error: option.None,
    login_in_flight: False,
    forgot_password_open: False,
    forgot_password_email: "",
    forgot_password_in_flight: False,
    forgot_password_result: option.None,
    forgot_password_error: option.None,
    forgot_password_copy_status: option.None,
    accept_invite: accept_invite.Model(
      token: "",
      state: accept_invite.NoToken,
      password: "",
      password_error: option.None,
      submit_error: option.None,
    ),
    reset_password: reset_password.Model(
      token: "",
      state: reset_password.NoToken,
      password: "",
      password_error: option.None,
      submit_error: option.None,
    ),
  )
}
