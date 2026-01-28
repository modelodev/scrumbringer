//// Reusable section header component for card detail tabs.
////
//// Provides consistent layout: [Title] ................ [Action Button]
//// Used by Tasks tab and Notes tab for visual consistency.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

/// Configuration for the card section header.
pub type Config(msg) {
  Config(
    /// The section title (e.g., "TAREAS", "NOTAS (2)")
    title: String,
    /// Button label (e.g., "+ Añadir tarea")
    button_label: String,
    /// Whether button is disabled
    button_disabled: Bool,
    /// Message to emit when button is clicked
    on_button_click: msg,
  )
}

/// Render a consistent section header with title and action button.
pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-section-header")], [
    span([attribute.class("card-section-title")], [text(config.title)]),
    button(
      [
        attribute.class("btn btn-sm btn-primary"),
        event.on_click(config.on_button_click),
        attribute.disabled(config.button_disabled),
      ],
      [text(config.button_label)],
    ),
  ])
}
