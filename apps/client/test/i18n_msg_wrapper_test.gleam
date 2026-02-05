import gleeunit/should

import scrumbringer_client/client_state
import scrumbringer_client/features/i18n/msg as i18n_messages

pub fn i18n_msg_wraps_locale_selected_test() {
  let inner = i18n_messages.LocaleSelected("es")
  let msg = client_state.i18n_msg(inner)

  msg
  |> should.equal(client_state.I18nMsg(inner))
}
