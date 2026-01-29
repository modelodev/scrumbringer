//// Tests for note_dialog UI component.

import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

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
  html |> string.contains("Nueva nota") |> should.be_true()
}

pub fn renders_placeholder_test() {
  // Given: Config with placeholder
  let config = Config(..default_config(), placeholder: "Escribe aquí...")

  // When: Render
  let html = render_to_string(config)

  // Then: Placeholder is present
  html |> string.contains("Escribe aquí...") |> should.be_true()
}

pub fn renders_error_when_present_test() {
  // Given: Config with error
  let config = Config(..default_config(), error: Some("Content is required"))

  // When: Render
  let html = render_to_string(config)

  // Then: Error message is present
  html |> string.contains("Content is required") |> should.be_true()
}

pub fn renders_cancel_button_test() {
  // Given: Config with cancel label
  let config = Config(..default_config(), cancel_label: "Cancelar")

  // When: Render
  let html = render_to_string(config)

  // Then: Cancel button is present
  html |> string.contains("Cancelar") |> should.be_true()
}

pub fn has_correct_css_classes_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has expected CSS classes
  html |> string.contains("note-dialog-overlay") |> should.be_true()
  html |> string.contains("note-dialog-header") |> should.be_true()
  html |> string.contains("note-dialog-body") |> should.be_true()
  html |> string.contains("note-dialog-footer") |> should.be_true()
}

pub fn has_aria_attributes_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has ARIA attributes for accessibility
  html |> string.contains("role=\"dialog\"") |> should.be_true()
  html |> string.contains("aria-modal=\"true\"") |> should.be_true()
  html |> string.contains("aria-label=\"Close\"") |> should.be_true()
}
