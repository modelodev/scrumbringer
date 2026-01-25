//// Shared error banner view.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/ui/icons

/// Render a standard error banner with warning icon.
pub fn view(message: String) -> Element(msg) {
  div([attribute.class("error-banner")], [
    span([attribute.class("error-banner-icon")], [
      icons.nav_icon(icons.Warning, icons.Small),
    ]),
    span([], [text(message)]),
  ])
}
