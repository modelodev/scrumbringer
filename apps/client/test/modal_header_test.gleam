//// Tests for modal_header UI component.

import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element
import lustre/element/html.{span, text}

import scrumbringer_client/ui/modal_header.{
  type Config, type ExtendedConfig, Config, ExtendedConfig,
}

// =============================================================================
// Test Helpers
// =============================================================================

fn render_to_string(config: Config(Nil)) -> String {
  modal_header.view(config) |> element.to_string()
}

fn default_config() -> Config(Nil) {
  Config(
    title: "Test Modal",
    icon: None,
    badges: [],
    meta: None,
    progress: None,
    on_close: Nil,
  )
}

// =============================================================================
// Tests
// =============================================================================

pub fn renders_title_test() {
  // Given: Config with title
  let config = Config(..default_config(), title: "My Modal Title")

  // When: Render
  let html = render_to_string(config)

  // Then: Title is present
  html |> string.contains("My Modal Title") |> should.be_true()
}

pub fn has_modal_header_class_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has modal-header class
  html |> string.contains("modal-header") |> should.be_true()
}

pub fn includes_close_button_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has close button with ARIA label
  html |> string.contains("aria-label=\"Close\"") |> should.be_true()
  html |> string.contains("modal-close") |> should.be_true()
}

pub fn renders_icon_when_provided_test() {
  // Given: Config with icon
  let icon = span([], [text("🎯")])
  let config = Config(..default_config(), icon: Some(icon))

  // When: Render
  let html = render_to_string(config)

  // Then: Icon is rendered
  html |> string.contains("modal-header-icon") |> should.be_true()
}

pub fn renders_badges_when_provided_test() {
  // Given: Config with badges
  let badge = span([], [text("Pendiente")])
  let config = Config(..default_config(), badges: [badge])

  // When: Render
  let html = render_to_string(config)

  // Then: Badges container is present
  html |> string.contains("modal-header-badges") |> should.be_true()
  html |> string.contains("Pendiente") |> should.be_true()
}

pub fn hides_badges_when_empty_test() {
  // Given: Config with no badges
  let config = Config(..default_config(), badges: [])

  // When: Render
  let html = render_to_string(config)

  // Then: No badges container
  html |> string.contains("modal-header-badges") |> should.be_false()
}

pub fn renders_meta_when_provided_test() {
  // Given: Config with meta
  let meta = text("2/10 completadas")
  let config = Config(..default_config(), meta: Some(meta))

  // When: Render
  let html = render_to_string(config)

  // Then: Meta is rendered
  html |> string.contains("modal-header-meta") |> should.be_true()
  html |> string.contains("2/10 completadas") |> should.be_true()
}

pub fn renders_progress_when_provided_test() {
  // Given: Config with progress
  let progress = span([], [text("50%")])
  let config = Config(..default_config(), progress: Some(progress))

  // When: Render
  let html = render_to_string(config)

  // Then: Progress is rendered
  html |> string.contains("modal-header-progress") |> should.be_true()
  html |> string.contains("50%") |> should.be_true()
}

pub fn hides_meta_row_when_both_empty_test() {
  // Given: Config with no meta and no progress
  let config = Config(..default_config(), meta: None, progress: None)

  // When: Render
  let html = render_to_string(config)

  // Then: No meta row
  html |> string.contains("modal-header-meta") |> should.be_false()
}

pub fn view_simple_renders_minimal_header_test() {
  // Given/When: Use view_simple
  let html =
    modal_header.view_simple("Simple Title", Nil)
    |> element.to_string()

  // Then: Has title and close button, no extras
  html |> string.contains("Simple Title") |> should.be_true()
  html |> string.contains("modal-close") |> should.be_true()
  html |> string.contains("modal-header-badges") |> should.be_false()
  html |> string.contains("modal-header-meta") |> should.be_false()
}

pub fn has_accessibility_attributes_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has ARIA attributes
  html |> string.contains("role=\"banner\"") |> should.be_true()
  html |> string.contains("id=\"modal-title\"") |> should.be_true()
}

// =============================================================================
// Extended Config Tests
// =============================================================================

fn default_extended_config() -> ExtendedConfig(Nil) {
  ExtendedConfig(
    title: "Extended Modal",
    icon: None,
    badges: [],
    meta: None,
    progress: None,
    on_close: Nil,
    header_class: "custom-header",
    title_row_class: "custom-title-row",
    title_class: "custom-title",
    title_id: "custom-modal-title",
    close_button_class: "custom-close-btn",
  )
}

pub fn view_extended_uses_custom_header_class_test() {
  // Given: Extended config with custom header class
  let config = default_extended_config()

  // When: Render with view_extended
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Uses custom header class
  html |> string.contains("custom-header") |> should.be_true()
}

pub fn view_extended_uses_custom_title_id_test() {
  // Given: Extended config with custom title ID
  let config = default_extended_config()

  // When: Render with view_extended
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Uses custom title ID for aria-labelledby
  html |> string.contains("id=\"custom-modal-title\"") |> should.be_true()
}

pub fn view_extended_uses_custom_close_button_class_test() {
  // Given: Extended config with custom close button class
  let config = default_extended_config()

  // When: Render with view_extended
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Close button uses custom class
  html |> string.contains("custom-close-btn") |> should.be_true()
}

pub fn extend_preserves_title_test() {
  // Given: Basic config
  let basic = default_config()

  // When: Extend it
  let extended = modal_header.extend(basic)

  // Then: Title is preserved
  extended.title |> should.equal("Test Modal")
}

pub fn extend_sets_default_classes_test() {
  // Given: Basic config
  let basic = default_config()

  // When: Extend it
  let extended = modal_header.extend(basic)

  // Then: Default classes are set
  extended.header_class |> should.equal("modal-header")
  extended.title_id |> should.equal("modal-title")
  extended.close_button_class |> should.equal("btn-icon modal-close")
}
