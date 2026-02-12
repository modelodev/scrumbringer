//// Reusable section header component for card/modal detail tabs.
////
//// Provides consistent layout: [Title] ................ [Action Button]
//// Used by card detail modal and task detail modal for visual consistency.
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

import gleam/option.{type Option, None, Some}
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

/// Extended configuration with optional class and button style overrides.
pub type ExtendedConfig(msg) {
  ExtendedConfig(
    /// The section title (e.g., "TAREAS", "NOTAS (2)")
    title: String,
    /// Button label (e.g., "+ Añadir tarea")
    button_label: String,
    /// Whether button is disabled
    button_disabled: Bool,
    /// Message to emit when button is clicked
    on_button_click: msg,
    /// Optional container CSS class (defaults to "card-section-header")
    container_class: Option(String),
    /// Optional button CSS class (defaults to "btn btn-sm btn-primary")
    button_class: Option(String),
  )
}

/// Render a consistent section header with title and action button.
pub fn view(config: Config(msg)) -> Element(msg) {
  view_internal(
    "card-section-header",
    "btn btn-sm btn-primary",
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
    "btn btn-sm btn-primary",
    config.title,
    config.button_label,
    config.button_disabled,
    config.on_button_click,
  )
}

/// Render a section header with full customization.
pub fn view_extended(config: ExtendedConfig(msg)) -> Element(msg) {
  let container_class = case config.container_class {
    Some(c) -> c
    None -> "card-section-header"
  }
  let button_class = case config.button_class {
    Some(c) -> c
    None -> "btn btn-sm btn-primary"
  }
  view_internal(
    container_class,
    button_class,
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
  button_class: String,
  title: String,
  button_label: String,
  button_disabled: Bool,
  on_button_click: msg,
) -> Element(msg) {
  div([attribute.class(container_class)], [
    span([attribute.class("card-section-title")], [text(title)]),
    button(
      [
        attribute.class(button_class),
        event.on_click(on_button_click),
        attribute.disabled(button_disabled),
      ],
      [text(button_label)],
    ),
  ])
}
