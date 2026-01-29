//// Reusable modal close button component.
////
//// ## Mission
////
//// Provides a consistent, accessible close button for modals and dialogs.
//// Extracted to eliminate duplication across dialog.gleam, note_dialog.gleam,
//// card_detail_modal.gleam, and pool/dialogs.gleam.
////
//// ## Usage
////
//// ```gleam
//// modal_close_button.view(CloseClicked)
//// ```

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, text}
import lustre/event

// =============================================================================
// View
// =============================================================================

/// Render a close button with ARIA accessibility.
pub fn view(on_close: msg) -> Element(msg) {
  button(
    [
      attribute.class("btn-icon modal-close"),
      attribute.type_("button"),
      event.on_click(on_close),
      attribute.attribute("aria-label", "Close"),
    ],
    [text("\u{2715}")],
  )
}

/// Render a close button with custom CSS class.
pub fn view_with_class(class: String, on_close: msg) -> Element(msg) {
  button(
    [
      attribute.class(class),
      attribute.type_("button"),
      event.on_click(on_close),
      attribute.attribute("aria-label", "Close"),
    ],
    [text("\u{2715}")],
  )
}
