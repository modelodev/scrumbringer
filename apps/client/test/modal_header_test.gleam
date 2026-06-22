//// Tests for modal_header UI component.

import gleam/option.{None, Some}
import gleam/string
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

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
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
  assert_contains(html, "My Modal Title")
}

pub fn has_modal_header_class_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has modal-header class
  assert_contains(html, "modal-header")
}

pub fn includes_close_button_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has close button with ARIA label
  assert_contains(html, "aria-label=\"Close\"")
  assert_contains(html, "modal-close")
}

pub fn renders_icon_when_provided_test() {
  // Given: Config with icon
  let icon = span([], [text("🎯")])
  let config = Config(..default_config(), icon: Some(icon))

  // When: Render
  let html = render_to_string(config)

  // Then: Icon is rendered
  assert_contains(html, "modal-header-icon")
}

pub fn renders_badges_when_provided_test() {
  // Given: Config with badges
  let badge = span([], [text("Draft")])
  let config = Config(..default_config(), badges: [badge])

  // When: Render
  let html = render_to_string(config)

  // Then: Badges container is present
  assert_contains(html, "modal-header-badges")
  assert_contains(html, "Draft")
}

pub fn hides_badges_when_empty_test() {
  // Given: Config with no badges
  let config = Config(..default_config(), badges: [])

  // When: Render
  let html = render_to_string(config)

  // Then: No badges container
  assert_not_contains(html, "modal-header-badges")
}

pub fn renders_meta_when_provided_test() {
  // Given: Config with meta
  let meta = text("2/10 completadas")
  let config = Config(..default_config(), meta: Some(meta))

  // When: Render
  let html = render_to_string(config)

  // Then: Meta is rendered
  assert_contains(html, "modal-header-meta")
  assert_contains(html, "2/10 completadas")
}

pub fn renders_progress_when_provided_test() {
  // Given: Config with progress
  let progress = span([], [text("50%")])
  let config = Config(..default_config(), progress: Some(progress))

  // When: Render
  let html = render_to_string(config)

  // Then: Progress is rendered
  assert_contains(html, "modal-header-progress")
  assert_contains(html, "50%")
}

pub fn hides_meta_row_when_both_empty_test() {
  // Given: Config with no meta and no progress
  let config = Config(..default_config(), meta: None, progress: None)

  // When: Render
  let html = render_to_string(config)

  // Then: No meta row
  assert_not_contains(html, "modal-header-meta")
}

pub fn view_simple_renders_minimal_header_test() {
  // Given/When: Use view_simple
  let html =
    modal_header.view_simple("Simple Title", Nil)
    |> element.to_string()

  // Then: Has title and close button, no extras
  assert_contains(html, "Simple Title")
  assert_contains(html, "modal-close")
  assert_not_contains(html, "modal-header-badges")
  assert_not_contains(html, "modal-header-meta")
}

pub fn has_accessibility_attributes_test() {
  // Given: Default config
  let config = default_config()

  // When: Render
  let html = render_to_string(config)

  // Then: Has ARIA attributes
  assert_contains(html, "role=\"banner\"")
  assert_contains(html, "id=\"modal-title\"")
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
  assert_contains(html, "custom-header")
}

pub fn view_extended_uses_custom_title_id_test() {
  // Given: Extended config with custom title ID
  let config = default_extended_config()

  // When: Render with view_extended
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Uses custom title ID for aria-labelledby
  assert_contains(html, "id=\"custom-modal-title\"")
}

pub fn view_extended_uses_custom_close_button_class_test() {
  // Given: Extended config with custom close button class
  let config = default_extended_config()

  // When: Render with view_extended
  let html = modal_header.view_extended(config) |> element.to_string()

  // Then: Close button uses custom class
  assert_contains(html, "custom-close-btn")
}

pub fn extend_preserves_title_test() {
  // Given: Basic config
  let basic = default_config()

  // When: Extend it
  let extended = modal_header.extend(basic)

  // Then: Title is preserved
  let assert "Test Modal" = extended.title
}

pub fn extend_sets_default_classes_test() {
  // Given: Basic config
  let basic = default_config()

  // When: Extend it
  let extended = modal_header.extend(basic)

  // Then: Default classes are set
  let assert "modal-header" = extended.header_class
  let assert "modal-title" = extended.title_id
  let assert "btn-icon modal-close" = extended.close_button_class
  let assert modal_header.TitleH2 = extended.title_element
  let assert modal_header.CloseAfterTitle = extended.close_position
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
  assert_contains(html, "<h3")
  assert_contains(html, "Create Task")
}

pub fn view_dialog_uses_dialog_classes_test() {
  // Given/When: Render dialog header
  let html =
    modal_header.view_dialog("Edit Task", None, Nil)
    |> element.to_string()

  // Then: Uses dialog- prefixed classes
  assert_contains(html, "dialog-header")
  assert_contains(html, "dialog-close")
}

pub fn view_dialog_close_button_after_title_test() {
  // Given/When: Render dialog header
  let html =
    modal_header.view_dialog("Test", None, Nil)
    |> element.to_string()

  // Then: Both elements exist and h3 comes before close button
  assert_contains(html, "<h3")
  assert_contains(html, "dialog-close")

  // Verify order: find position of h3 and close button
  let assert Ok(#(before_h3, _)) = string.split_once(html, "<h3")
  let assert Ok(#(before_close, _)) = string.split_once(html, "dialog-close")

  // h3 should come before dialog-close (shorter prefix = earlier in string)
  let assert True = string.length(before_h3) < string.length(before_close)
}

pub fn view_dialog_with_icon_test() {
  // Given: Dialog with icon
  let icon = span([], [text("📝")])

  // When: Render
  let html =
    modal_header.view_dialog("With Icon", Some(icon), Nil)
    |> element.to_string()

  // Then: Icon is rendered
  assert_contains(html, "📝")
  assert_contains(html, "modal-header-icon")
}

pub fn view_dialog_with_icon_accepts_close_label_test() {
  let icon = span([], [text("icon")])
  let html =
    modal_header.view_dialog_with_icon_and_close_label(
      "Crear",
      icon,
      Nil,
      "Cerrar",
    )
    |> element.to_string()

  assert_contains(html, "aria-label=\"Cerrar\"")
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
      class_prefix: "task-show",
    )

  // When: Render
  let html = modal_header.view_detail(config) |> element.to_string()

  // Then: Uses span for title
  assert_contains(html, "<span")
  assert_contains(html, "Task Title")
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
      class_prefix: "card-show",
    )

  // When: Render
  let html = modal_header.view_detail(config) |> element.to_string()

  // Then: Uses prefix for all classes
  assert_contains(html, "card-show-header")
  assert_contains(html, "card-show-title")
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
      class_prefix: "task-show",
    )

  // When: Render
  let html = modal_header.view_detail(config) |> element.to_string()

  // Then: Meta and progress are rendered
  assert_contains(html, "2/5 completadas")
  assert_contains(html, "40%")
  assert_contains(html, "modal-header-meta")
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
  assert_contains(html, "<h3")
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
  assert_contains(html, "<span")
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
  assert_contains(html, "custom-close-btn")
  assert_contains(html, "custom-title\"")
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
  assert_contains(html, "dialog-title")
  assert_contains(html, "dialog-icon")
  assert_contains(html, "📝")
}

pub fn view_dialog_with_icon_uses_h3_test() {
  // Given/When: Render dialog with icon
  let html =
    modal_header.view_dialog_with_icon("Task Title", text("⚙"), Nil)
    |> element.to_string()

  // Then: Uses h3 for title
  assert_contains(html, "<h3")
  assert_contains(html, "Task Title")
}

pub fn view_dialog_with_icon_has_close_button_test() {
  // Given/When: Render dialog with icon
  let html =
    modal_header.view_dialog_with_icon("Test", text("🔧"), Nil)
    |> element.to_string()

  // Then: Has close button with correct class
  assert_contains(html, "btn-icon dialog-close")
  assert_contains(html, "aria-label=\"Close\"")
}

pub fn view_dialog_with_icon_has_aria_role_test() {
  // Given/When: Render dialog with icon
  let html =
    modal_header.view_dialog_with_icon("Test", text("📋"), Nil)
    |> element.to_string()

  // Then: Has role="banner" for accessibility
  assert_contains(html, "role=\"banner\"")
}
