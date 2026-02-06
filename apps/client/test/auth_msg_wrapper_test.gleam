import gleeunit/should

import scrumbringer_client/client_state
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/token_flow

pub fn auth_msg_wraps_accept_invite_test() {
  let inner = auth_messages.AcceptInvite(token_flow.ErrorDismissed)
  let msg = client_state.auth_msg(inner)

  msg
  |> should.equal(client_state.AuthMsg(inner))
}

pub fn auth_msg_wraps_reset_password_test() {
  let inner = auth_messages.ResetPassword(token_flow.ErrorDismissed)
  let msg = client_state.auth_msg(inner)

  msg
  |> should.equal(client_state.AuthMsg(inner))
}
