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
    title_element: modal_header.TitleH2,
    close_position: modal_header.CloseAfterTitle,
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
  extended.title_element |> should.equal(modal_header.TitleH2)
  extended.close_position |> should.equal(modal_header.CloseAfterTitle)
}

// =============================================================================
// view_dialog Tests
// =============================================================================

pub fn view_dialog_renders_h3_title_test() {
  // Given/When: Render dialog header
  let html =
    modal_header.view_dialog("Create Task", None, Nil)
    |> element.to_string()

  // Then: Uses h3 instead of h2
  html |> string.contains("<h3") |> should.be_true()
  html |> string.contains("Create Task") |> should.be_true()
}

pub fn view_dialog_uses_dialog_classes_test() {
  // Given/When: Render dialog header
  let html =
    modal_header.view_dialog("Edit Task", None, Nil)
    |> element.to_string()

  // Then: Uses dialog- prefixed classes
  html |> string.contains("dialog-header") |> should.be_true()
  html |> string.contains("dialog-close") |> should.be_true()
}

pub fn view_dialog_close_button_after_title_test() {
  // Given/When: Render dialog header
  let html =
    modal_header.view_dialog("Test", None, Nil)
    |> element.to_string()

  // Then: Both elements exist and h3 comes before close button
  html |> string.contains("<h3") |> should.be_true()
  html |> string.contains("dialog-close") |> should.be_true()

  // Verify order: find position of h3 and close button
  let assert Ok(#(before_h3, _)) = string.split_once(html, "<h3")
  let assert Ok(#(before_close, _)) = string.split_once(html, "dialog-close")

  // h3 should come before dialog-close (shorter prefix = earlier in string)
  { string.length(before_h3) < string.length(before_close) } |> should.be_true()
}

pub fn view_dialog_with_icon_test() {
  // Given: Dialog with icon
  let icon = span([], [text("📝")])

  // When: Render
  let html =
    modal_header.view_dialog("With Icon", Some(icon), Nil)
    |> element.to_string()

  // Then: Icon is rendered
  html |> string.contains("📝") |> should.be_true()
  html |> string.contains("modal-header-icon") |> should.be_true()
}

// =============================================================================
// view_detail Tests
// =============================================================================

pub fn view_detail_renders_span_title_test() {
  // Given: Detail config
  let config =
    modal_header.DetailConfig(
      title: "Task Title",
      icon: None,
      meta: None,
      progress: None,
      on_close: Nil,
      class_prefix: "task-detail",
    )

  // When: Render
  let html = modal_header.view_detail(config) |> element.to_string()

  // Then: Uses span for title
  html |> string.contains("<span") |> should.be_true()
  html |> string.contains("Task Title") |> should.be_true()
}

pub fn view_detail_uses_class_prefix_test() {
  // Given: Detail config with custom prefix
  let config =
    modal_header.DetailConfig(
      title: "Card Title",
      icon: None,
      meta: None,
      progress: None,
      on_close: Nil,
      class_prefix: "card-detail",
    )

  // When: Render
  let html = modal_header.view_detail(config) |> element.to_string()

  // Then: Uses prefix for all classes
  html |> string.contains("card-detail-header") |> should.be_true()
  html |> string.contains("card-detail-title") |> should.be_true()
}

pub fn view_detail_with_meta_and_progress_test() {
  // Given: Detail config with meta and progress
  let config =
    modal_header.DetailConfig(
      title: "With Meta",
      icon: None,
      meta: Some(text("2/5 completadas")),
      progress: Some(span([], [text("40%")])),
      on_close: Nil,
      class_prefix: "task-detail",
    )

  // When: Render
  let html = modal_header.view_detail(config) |> element.to_string()

  // Then: Meta and progress are rendered
  html |> string.contains("2/5 completadas") |> should.be_true()
  html |> string.contains("40%") |> should.be_true()
  html |> string.contains("modal-header-meta") |> should.be_true()
}

// =============================================================================
// TitleElement Type Tests
// =============================================================================

pub fn title_h3_renders_h3_tag_test() {
  // Given: Extended config with TitleH3
  let config =
    ExtendedConfig(
      ..default_extended_config(),
      title_element: modal_header.TitleH3,
    )

  // When: Render
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Uses h3 tag
  html |> string.contains("<h3") |> should.be_true()
}

pub fn title_span_renders_span_tag_test() {
  // Given: Extended config with TitleSpan
  let config =
    ExtendedConfig(
      ..default_extended_config(),
      title_element: modal_header.TitleSpan,
    )

  // When: Render
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Uses span tag (not h2 or h3)
  html |> string.contains("<span") |> should.be_true()
}

// =============================================================================
// ClosePosition Type Tests
// =============================================================================

pub fn close_before_title_order_test() {
  // Given: Extended config with CloseBeforeTitle
  let config =
    ExtendedConfig(
      ..default_extended_config(),
      close_position: modal_header.CloseBeforeTitle,
    )

  // When: Render
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Both close button and title class exist
  html |> string.contains("custom-close-btn") |> should.be_true()
  html |> string.contains("custom-title\"") |> should.be_true()
}

// =============================================================================
// view_dialog_with_icon Tests
// =============================================================================

pub fn view_dialog_with_icon_renders_dialog_title_wrapper_test() {
  // Given/When: Render dialog with icon
  let html =
    modal_header.view_dialog_with_icon("Create Task", text("📝"), Nil)
    |> element.to_string()

  // Then: Has dialog-title wrapper containing icon
  html |> string.contains("dialog-title") |> should.be_true()
  html |> string.contains("dialog-icon") |> should.be_true()
  html |> string.contains("📝") |> should.be_true()
}

pub fn view_dialog_with_icon_uses_h3_test() {
  // Given/When: Render dialog with icon
  let html =
    modal_header.view_dialog_with_icon("Task Title", text("⚙"), Nil)
    |> element.to_string()

  // Then: Uses h3 for title
  html |> string.contains("<h3") |> should.be_true()
  html |> string.contains("Task Title") |> should.be_true()
}

pub fn view_dialog_with_icon_has_close_button_test() {
  // Given/When: Render dialog with icon
  let html =
    modal_header.view_dialog_with_icon("Test", text("🔧"), Nil)
    |> element.to_string()

  // Then: Has close button with correct class
  html |> string.contains("btn-icon dialog-close") |> should.be_true()
  html |> string.contains("aria-label=\"Close\"") |> should.be_true()
}

pub fn view_dialog_with_icon_has_aria_role_test() {
  // Given/When: Render dialog with icon
  let html =
    modal_header.view_dialog_with_icon("Test", text("📋"), Nil)
    |> element.to_string()

  // Then: Has role="banner" for accessibility
  html |> string.contains("role=\"banner\"") |> should.be_true()
}
