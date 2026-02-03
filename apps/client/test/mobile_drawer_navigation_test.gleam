import gleeunit/should

import scrumbringer_client/client_state
import scrumbringer_client/client_update
import scrumbringer_client/permissions
import scrumbringer_client/router

pub fn navigate_to_closes_mobile_drawers_test() {
  let model =
    client_state.default_model()
    |> client_state.update_ui(fn(ui) {
      client_state.UiModel(..ui, mobile_drawer: client_state.DrawerLeftOpen)
    })

  let #(next_model, _) =
    client_update.update(
      model,
      client_state.NavigateTo(
        router.Org(permissions.Invites),
        client_state.Push,
      ),
    )

  next_model.ui.mobile_drawer
  |> should.equal(client_state.DrawerClosed)
}
