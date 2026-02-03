//// Skeleton loading placeholders.
////
//// ## Mission
////
//// Provide animated placeholder UI during content loading.
////
//// ## Responsibilities
////
//// - Render skeleton lines and shapes with pulse animation.
////
//// ## Non-responsibilities
////
//// - State management (caller handles Remote state).
////
//// ## Relations
////
//// - **data_table.gleam**: Can use skeleton for loading state.
//// - **Remote type**: Complements Loading variant rendering.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

pub fn skeleton_line(width: String, height: String) -> Element(msg) {
  div(
    [
      attribute.class("skeleton"),
      attribute.style("width", width),
      attribute.style("height", height),
    ],
    [],
  )
}

pub fn skeleton_card() -> Element(msg) {
  div(
    [
      attribute.class("skeleton"),
      attribute.style("width", "100%"),
      attribute.style("height", "120px"),
    ],
    [],
  )
}
