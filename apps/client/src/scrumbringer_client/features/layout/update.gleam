//// Layout feature update handlers.

import lustre/effect.{type Effect}

import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/layout/msg as layout_messages

/// Updates layout state for a message.
pub fn update(
  model: client_state.Model,
  msg: layout_messages.Msg,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case msg {
    layout_messages.MemberPanelToggled -> #(
      client_state.update_member(model, fn(member) {
        let pool = member.pool
        member_state.MemberModel(
          ..member,
          pool: member_pool.Model(
            ..pool,
            member_panel_expanded: !model.member.pool.member_panel_expanded,
          ),
        )
      }),
      effect.none(),
    )
    layout_messages.MobileLeftDrawerToggled -> #(
      client_state.update_ui(model, fn(ui) {
        ui_state.UiModel(
          ..ui,
          mobile_drawer: client_state.toggle_left_drawer(model.ui.mobile_drawer),
        )
      }),
      effect.none(),
    )
    layout_messages.MobileRightDrawerToggled -> #(
      client_state.update_ui(model, fn(ui) {
        ui_state.UiModel(
          ..ui,
          mobile_drawer: client_state.toggle_right_drawer(
            model.ui.mobile_drawer,
          ),
        )
      }),
      effect.none(),
    )
    layout_messages.MobileDrawersClosed -> #(
      client_state.update_ui(model, fn(ui) {
        ui_state.UiModel(
          ..ui,
          mobile_drawer: client_state.close_drawers(model.ui.mobile_drawer),
        )
      }),
      effect.none(),
    )
    layout_messages.SidebarConfigToggled -> {
      let next_state =
        client_state.toggle_sidebar_config(model.ui.sidebar_collapse)
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, sidebar_collapse: next_state)
        }),
        app_effects.save_sidebar_state(next_state),
      )
    }
    layout_messages.SidebarOrgToggled -> {
      let next_state =
        client_state.toggle_sidebar_org(model.ui.sidebar_collapse)
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, sidebar_collapse: next_state)
        }),
        app_effects.save_sidebar_state(next_state),
      )
    }
    layout_messages.PreferencesPopupToggled -> #(
      client_state.update_ui(model, fn(ui) {
        ui_state.UiModel(
          ..ui,
          preferences_popup_open: !model.ui.preferences_popup_open,
        )
      }),
      effect.none(),
    )
  }
}
