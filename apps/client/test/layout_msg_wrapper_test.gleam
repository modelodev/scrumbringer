import gleeunit/should

import scrumbringer_client/client_state
import scrumbringer_client/features/layout/msg as layout_messages

pub fn layout_msg_wraps_mobile_drawer_test() {
  let inner = layout_messages.MobileLeftDrawerToggled
  let msg = client_state.layout_msg(inner)

  msg
  |> should.equal(client_state.LayoutMsg(inner))
}
