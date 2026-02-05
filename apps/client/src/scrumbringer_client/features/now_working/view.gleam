//// Now Working feature views.
////
//// Delegates to panel/mobile components (Phase 1 modularization).

import lustre/element.{type Element}

import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/features/now_working/panel as now_working_panel

/// Right panel view for Now Working.
pub fn view_panel(model: Model) -> Element(Msg) {
  now_working_panel.view(model)
}

/// Mobile mini-bar view for Now Working.
pub fn view_mini_bar(model: Model) -> Element(Msg) {
  now_working_mobile.view_mini_bar(model)
}

/// Mobile overlay view for Now Working.
pub fn view_overlay(model: Model) -> Element(Msg) {
  now_working_mobile.view_overlay(model)
}

/// Mobile panel sheet view for Now Working.
pub fn view_panel_sheet(model: Model, user_id: Int) -> Element(Msg) {
  now_working_mobile.view_panel_sheet(model, user_id)
}
