//// Tests for note_dialog UI component.

import gleam/option.{None, Some}
import lustre/element
import support/render_assertions

import scrumbringer_client/ui/note_dialog.{type Config, Config}

// =============================================================================
// Test Helpers
// =============================================================================

fn render_to_string(config: Config(Nil)) -> String {
  note_dialog.view(config) |> element.to_string()
}

fn default_config() -> Config(Nil) {
  Config(
    title: "Add Note",
    content: "",
    placeholder: "Write your note...",
    error: None,
    submit_label: "Add",
    submit_disabled: True,
    cancel_label: "Cancel",
    close_label: "Close",
    on_content_change: fn(_) { Nil },
    on_submit: Nil,
    on_close: Nil,
  )
}

// =============================================================================
// Tests
// =============================================================================

pub fn renders_title_test() {
  // Given: Config with title
  let config = Config(..default_config(), title: "Nueva nota")

  // When: Render
  let html = render_to_string(config)

  // Then: Title is present
  render_assertions.contains(html, "Nueva nota")
}

pub fn renders_placeholder_test() {
  // Given: Config with placeholder
  let config = Config(..default_config(), placeholder: "Escribe aquí...")

  // When: Render
  let html = render_to_string(config)

  // Then: Placeholder is present
  render_assertions.contains(html, "Escribe aquí...")
}

pub fn renders_error_when_present_test() {
  // Given: Config with error
  let config = Config(..default_config(), error: Some("Content is required"))

  // When: Render
  let html = render_to_string(config)

  // Then: Error message is present
  render_assertions.contains(html, "Content is required")
}

pub fn renders_cancel_button_test() {
  // Given: Config with cancel label
  let config = Config(..default_config(), cancel_label: "Cancelar")

  // When: Render
  let html = render_to_string(config)

  // Then: Cancel button is present
  render_assertions.contains(html, "Cancelar")
}

pub fn has_correct_css_classes_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has expected CSS classes
  render_assertions.contains(html, "note-dialog-overlay")
  render_assertions.contains(html, "note-dialog-header")
  render_assertions.contains(html, "note-dialog-body")
  render_assertions.contains(html, "note-dialog-footer")
}

pub fn has_aria_attributes_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has ARIA attributes for accessibility
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(html, "aria-label=\"Close\"")
}

pub fn uses_configured_close_label_test() {
  let config = Config(..default_config(), close_label: "Cerrar")

  let html = render_to_string(config)

  render_assertions.contains(html, "aria-label=\"Cerrar\"")
}
