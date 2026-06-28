//// Reusable section header component for Card Show and Task Show tabs.
////
//// Provides consistent layout: [Title] ................ [Action Button]
//// Used by Card Show and Task Show for visual consistency.
////
//// ## Usage
////
//// ```gleam
//// // Standard card section header
//// card_section_header.view(card_section_header.Config(
////   title: "TAREAS (2)",
////   button_label: "+ Añadir tarea",
////   button_disabled: False,
////   on_button_click: AddTaskClicked,
//// ))
////
//// // With custom CSS class
//// card_section_header.view_with_class(
////   "card-section-header",
////   card_section_header.Config(
////     title: "Notas",
////     button_label: "+ Añadir nota",
////     button_disabled: False,
////     on_button_click: AddNoteClicked,
////   ),
//// )
//// ```

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/ui/button

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
  view_internal(
    "card-section-header",
    config.title,
    config.button_label,
    config.button_disabled,
    config.on_button_click,
  )
}

/// Render a section header with custom container CSS class.
pub fn view_with_class(class: String, config: Config(msg)) -> Element(msg) {
  view_internal(
    class,
    config.title,
    config.button_label,
    config.button_disabled,
    config.on_button_click,
  )
}

// =============================================================================
// Internal
// =============================================================================

fn view_internal(
  container_class: String,
  title: String,
  button_label: String,
  button_disabled: Bool,
  on_button_click: msg,
) -> Element(msg) {
  div([attribute.class(container_class)], [
    span([attribute.class("card-section-title")], [text(title)]),
    button.text(
      button_label,
      on_button_click,
      button.Primary,
      button.EntityAction,
    )
      |> button.with_disabled(button_disabled)
      |> button.view,
  ])
}
