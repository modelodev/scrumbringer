//// Layout feature update handlers.

import lustre/effect.{type Effect}

import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/layout/msg as layout_messages

pub type Model {
  Model(ui: ui_state.UiModel, member_panel_expanded: Bool)
}

/// Updates layout state for a message.
pub fn update(
  model: Model,
  msg: layout_messages.Msg,
) -> #(Model, Effect(parent_msg)) {
  case msg {
    layout_messages.MemberPanelToggled -> #(
      Model(..model, member_panel_expanded: !model.member_panel_expanded),
      effect.none(),
    )
    layout_messages.MobileLeftDrawerToggled -> #(
      Model(
        ..model,
        ui: ui_state.UiModel(
          ..model.ui,
          mobile_drawer: ui_state.toggle_left_drawer(model.ui.mobile_drawer),
        ),
      ),
      effect.none(),
    )
    layout_messages.MobileRightDrawerToggled -> #(
      Model(
        ..model,
        ui: ui_state.UiModel(
          ..model.ui,
          mobile_drawer: ui_state.toggle_right_drawer(model.ui.mobile_drawer),
        ),
      ),
      effect.none(),
    )
    layout_messages.MobileDrawersClosed -> #(
      Model(
        ..model,
        ui: ui_state.UiModel(
          ..model.ui,
          mobile_drawer: ui_state.close_drawers(model.ui.mobile_drawer),
        ),
      ),
      effect.none(),
    )
    layout_messages.SidebarConfigToggled -> {
      let next_state = ui_state.toggle_sidebar_config(model.ui.sidebar_collapse)
      #(
        Model(
          ..model,
          ui: ui_state.UiModel(..model.ui, sidebar_collapse: next_state),
        ),
        app_effects.save_sidebar_state(next_state),
      )
    }
    layout_messages.SidebarOrgToggled -> {
      let next_state = ui_state.toggle_sidebar_org(model.ui.sidebar_collapse)
      #(
        Model(
          ..model,
          ui: ui_state.UiModel(..model.ui, sidebar_collapse: next_state),
        ),
        app_effects.save_sidebar_state(next_state),
      )
    }
    layout_messages.PreferencesPopupToggled -> #(
      Model(
        ..model,
        ui: ui_state.UiModel(
          ..model.ui,
          preferences_popup_open: !model.ui.preferences_popup_open,
        ),
      ),
      effect.none(),
    )
  }
}
