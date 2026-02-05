//// Auth feature state types.
////
//// Owns the authentication-related model state.

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
