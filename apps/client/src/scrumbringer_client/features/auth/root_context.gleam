//// Root-aware auth update context.

import scrumbringer_client/client_state
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/features/auth/update as auth_workflow
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn from_state(
  model: client_state.Model,
) -> auth_workflow.Context(client_state.Msg) {
  auth_workflow.Context(
    on_login_dom_values_read: fn(email, password) {
      client_state.auth_msg(auth_messages.LoginDomValuesRead(email, password))
    },
    on_login_finished: fn(result) {
      client_state.auth_msg(auth_messages.LoginFinished(result))
    },
    on_forgot_password_finished: fn(result) {
      client_state.auth_msg(auth_messages.ForgotPasswordFinished(result))
    },
    on_forgot_password_copy_finished: fn(ok) {
      client_state.auth_msg(auth_messages.ForgotPasswordCopyFinished(ok))
    },
    on_logout_finished: fn(result) {
      client_state.auth_msg(auth_messages.LogoutFinished(result))
    },
    on_accept_invite: fn(inner) {
      client_state.auth_msg(auth_messages.AcceptInvite(inner))
    },
    on_reset_password: fn(inner) {
      client_state.auth_msg(auth_messages.ResetPassword(inner))
    },
    email_and_password_required: i18n.t(
      model.ui.locale,
      i18n_text.EmailAndPasswordRequired,
    ),
    email_required: i18n.t(model.ui.locale, i18n_text.EmailRequired),
    invalid_credentials: i18n.t(model.ui.locale, i18n_text.InvalidCredentials),
    copying: i18n.t(model.ui.locale, i18n_text.Copying),
    copied: i18n.t(model.ui.locale, i18n_text.Copied),
    copy_failed: i18n.t(model.ui.locale, i18n_text.CopyFailed),
  )
}
