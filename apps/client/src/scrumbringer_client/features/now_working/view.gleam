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

/// Mobile view for Now Working.
pub fn view_mobile(model: Model) -> Element(Msg) {
  now_working_mobile.view(model)
}
