//// Error notice helpers for consistent inline error display.
////
//// Wraps error_banner with optional dismiss action for inline blocks.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h2, text}

import scrumbringer_client/ui/button
import scrumbringer_client/ui/error_banner

pub fn view(message: String) -> Element(msg) {
  div([attribute.class("error")], [error_banner.view(message)])
}

pub fn view_dismissible(
  message: String,
  dismiss_label: String,
  on_dismiss: msg,
) -> Element(msg) {
  div([attribute.class("error")], [
    error_banner.view(message),
    button.text(dismiss_label, on_dismiss, button.Ghost, button.EntityAction)
      |> button.with_size(button.ExtraSmall)
      |> button.view,
  ])
}

pub fn view_panel(title: String, message: String) -> Element(msg) {
  div([attribute.class("panel")], [
    h2([], [text(title)]),
    view(message),
  ])
}
