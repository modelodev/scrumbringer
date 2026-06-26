//// Compact guidance for operational screens.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{p, text}

pub fn section(message: String) -> Element(msg) {
  p([attribute.class("guidance guidance-section")], [text(message)])
}
