//// Reusable CRUD dialog headers.
////
//// The product currently uses two localized dialog header contracts:
//// one with an optional leading icon and one with an icon wrapped in the
//// dialog title. Broader modal/detail header APIs live in the inspector
//// components that render those surfaces.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, span, text}

import scrumbringer_client/ui/modal_close_button

/// Render a CRUD dialog header with a localized close button label.
pub fn view_dialog_with_close_label(
  title: String,
  icon: Option(Element(msg)),
  on_close: msg,
  close_label: String,
) -> Element(msg) {
  div(
    [
      attribute.class("dialog-header"),
      attribute.attribute("role", "banner"),
    ],
    [
      case icon {
        Some(i) -> div([attribute.class("modal-header-icon")], [i])
        None -> element.none()
      },
      h3([attribute.id("dialog-title")], [text(title)]),
      modal_close_button.view_with_label_and_class(
        close_label,
        "dialog-close",
        on_close,
      ),
    ],
  )
}

/// Render a CRUD dialog header with icon and a localized close button label.
pub fn view_dialog_with_icon_and_close_label(
  title: String,
  icon: Element(msg),
  on_close: msg,
  close_label: String,
) -> Element(msg) {
  div(
    [
      attribute.class("dialog-header"),
      attribute.attribute("role", "banner"),
    ],
    [
      div([attribute.class("dialog-title")], [
        span([attribute.class("dialog-icon")], [icon]),
        h3([attribute.id("dialog-title")], [text(title)]),
      ]),
      modal_close_button.view_with_label_and_class(
        close_label,
        "btn-icon dialog-close",
        on_close,
      ),
    ],
  )
}
