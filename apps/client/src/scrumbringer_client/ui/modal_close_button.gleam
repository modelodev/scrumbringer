//// Reusable modal close button component.
////
//// ## Mission
////
//// Provides a consistent, accessible close button for modals and dialogs.
//// Extracted to eliminate duplication across dialog.gleam, note_dialog.gleam,
//// card_show.gleam, and pool/task_show.gleam.
////
//// ## Usage
////
//// ```gleam
//// modal_close_button.view(CloseClicked)
//// ```

import gleam/list
import gleam/option.{type Option, None, Some}
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
  view_with_label_and_class("Close", class, on_close)
}

/// Render a close button with a custom accessible label and CSS class.
pub fn view_with_label_and_class(
  label: String,
  class: String,
  on_close: msg,
) -> Element(msg) {
  view_with_label_class_and_testid(label, class, on_close, None)
}

/// Render a close button with optional test target for high-level surfaces.
pub fn view_with_label_class_and_testid(
  label: String,
  class: String,
  on_close: msg,
  testid: Option(String),
) -> Element(msg) {
  button(
    list.append(
      [
        attribute.class(class),
        attribute.type_("button"),
        event.on_click(on_close),
        attribute.attribute("aria-label", label),
      ],
      testid_attr(testid),
    ),
    [text("\u{2715}")],
  )
}

fn testid_attr(testid: Option(String)) -> List(attribute.Attribute(msg)) {
  case testid {
    Some(value) -> [attribute.attribute("data-testid", value)]
    None -> []
  }
}
