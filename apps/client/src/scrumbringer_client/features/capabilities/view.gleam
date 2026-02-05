//// Capabilities feature views.
////
//// Delegates to admin views (Phase 1 modularization).

import lustre/element.{type Element}

import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/features/admin/view as admin_view

/// Capabilities management view (admin section).
pub fn view(model: Model) -> Element(Msg) {
  admin_view.view_capabilities(model)
}
