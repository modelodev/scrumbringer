//// Shared admin surface composition.
////
//// Keeps admin views on a predictable rhythm:
//// header, optional filters, then content.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

pub fn view(
  header: Element(msg),
  content: Element(msg),
  overlays: List(Element(msg)),
) -> Element(msg) {
  div([attribute.class("section admin-surface")], [
    header,
    div([attribute.class("admin-surface-content")], [content]),
    ..overlays
  ])
}

pub fn view_with_filters(
  header: Element(msg),
  filters: Element(msg),
  content: Element(msg),
  overlays: List(Element(msg)),
) -> Element(msg) {
  div([attribute.class("section admin-surface")], [
    header,
    div([attribute.class("admin-surface-filters")], [filters]),
    div([attribute.class("admin-surface-content")], [content]),
    ..overlays
  ])
}
