//// Auth feature messages.
////
//// Wraps all authentication-related messages including accept-invite
//// and reset-password flows.

import domain/api_error.{type ApiResult}
import domain/user.{type User}

import scrumbringer_client/accept_invite
import scrumbringer_client/api/auth.{type PasswordReset}
import scrumbringer_client/reset_password

/// Represents Auth Msg.
pub type Msg {
  LoginEmailChanged(String)
  LoginPasswordChanged(String)
  LoginSubmitted
  LoginDomValuesRead(String, String)
  LoginFinished(ApiResult(User))
  ForgotPasswordClicked
  ForgotPasswordEmailChanged(String)
  ForgotPasswordSubmitted
  ForgotPasswordFinished(ApiResult(PasswordReset))
  ForgotPasswordCopyClicked
  ForgotPasswordCopyFinished(Bool)
  ForgotPasswordDismissed
  LogoutClicked
  LogoutFinished(ApiResult(Nil))
  AcceptInvite(accept_invite.Msg)
  ResetPassword(reset_password.Msg)
}
