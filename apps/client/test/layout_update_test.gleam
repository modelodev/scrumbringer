import lustre/effect

import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/layout/msg as layout_messages
import scrumbringer_client/features/layout/update as layout_update

fn default_layout() -> layout_update.Model {
  layout_update.Model(
    ui: ui_state.default_model(),
    member_panel_expanded: False,
  )
}

pub fn member_panel_toggle_updates_local_layout_model_test() {
  let #(next_model, fx) =
    layout_update.update(default_layout(), layout_messages.MemberPanelToggled)

  let assert True = next_model.member_panel_expanded
  let assert True = fx == effect.none()
}

pub fn mobile_left_drawer_toggle_updates_local_ui_test() {
  let #(next_model, fx) =
    layout_update.update(
      default_layout(),
      layout_messages.MobileLeftDrawerToggled,
    )

  let assert ui_state.DrawerLeftOpen = next_model.ui.mobile_drawer
  let assert True = fx == effect.none()
}

pub fn preferences_popup_toggle_updates_local_ui_test() {
  let #(next_model, fx) =
    layout_update.update(
      default_layout(),
      layout_messages.PreferencesPopupToggled,
    )

  let assert True = next_model.ui.preferences_popup_open
  let assert True = fx == effect.none()
}
