//// Error notice helpers for consistent inline error display.
////
//// Wraps error_banner with optional dismiss action for inline blocks.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, text}
import lustre/event

import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/error_banner

pub fn view(message: String) -> Element(msg) {
  div([attrs.error()], [error_banner.view(message)])
}

pub fn view_dismissible(
  message: String,
  dismiss_label: String,
  on_dismiss: msg,
) -> Element(msg) {
  div([attrs.error()], [
    error_banner.view(message),
    button([attribute.class("btn-xs"), event.on_click(on_dismiss)], [
      text(dismiss_label),
    ]),
  ])
}

pub fn view_panel(title: String, message: String) -> Element(msg) {
  div([attribute.class("panel")], [
    h2([], [text(title)]),
    view(message),
  ])
}
