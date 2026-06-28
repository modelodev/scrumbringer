//// Tests for modal_close_button UI component.

import gleam/option.{Some}
import lustre/element
import scrumbringer_client/ui/modal_close_button
import support/render_assertions

// =============================================================================
// Test Helpers
// =============================================================================

fn render_to_string() -> String {
  modal_close_button.view(Nil) |> element.to_string()
}

// =============================================================================
// Tests
// =============================================================================

pub fn renders_close_button_with_aria_label_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Has ARIA label for accessibility
  render_assertions.contains(html, "aria-label")
  render_assertions.contains(html, "Close")
}

pub fn renders_close_button_with_correct_class_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Has expected CSS classes
  render_assertions.contains(html, "btn-icon")
  render_assertions.contains(html, "modal-close")
}

pub fn renders_stable_entity_show_close_target_test() {
  let html =
    modal_close_button.view_with_label_class_and_testid(
      "Close",
      "btn-icon modal-close",
      Nil,
      Some("entity-show-close"),
    )
    |> element.to_string()

  render_assertions.contains(html, "data-testid=\"entity-show-close\"")
}

pub fn renders_close_icon_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Contains close icon (×)
  render_assertions.contains(html, "\u{2715}")
}

pub fn view_with_class_uses_custom_class_test() {
  // Given/When: Render with custom class
  let html =
    modal_close_button.view_with_class("my-custom-close", Nil)
    |> element.to_string()

  // Then: Uses custom class
  render_assertions.contains(html, "my-custom-close")
}
