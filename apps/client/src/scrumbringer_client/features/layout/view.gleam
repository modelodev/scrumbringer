//// Layout feature views.
////
//// Wrapper around the three-panel layout API (Phase 1 modularization).

import lustre/element.{type Element}

import scrumbringer_client/features/layout/three_panel_layout

/// Render the three-panel layout.
pub fn view(
  left: Element(msg),
  center: Element(msg),
  right: Element(msg),
) -> Element(msg) {
  three_panel_layout.view(left, center, right)
}

/// Render the three-panel layout with i18n labels.
pub fn view_i18n(
  left: Element(msg),
  center: Element(msg),
  right: Element(msg),
  nav_label: String,
  aside_label: String,
) -> Element(msg) {
  three_panel_layout.view_i18n(left, center, right, nav_label, aside_label)
}
