//// Tests for modal_close_button UI component.

import gleam/string
import lustre/element
import scrumbringer_client/ui/modal_close_button

// =============================================================================
// Test Helpers
// =============================================================================

fn render_to_string() -> String {
  modal_close_button.view(Nil) |> element.to_string()
}

fn assert_contains(haystack: String, needle: String) {
  let assert True = string.contains(haystack, needle)
}

// =============================================================================
// Tests
// =============================================================================

pub fn renders_close_button_with_aria_label_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Has ARIA label for accessibility
  assert_contains(html, "aria-label")
  assert_contains(html, "Close")
}

pub fn renders_close_button_with_correct_class_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Has expected CSS classes
  assert_contains(html, "btn-icon")
  assert_contains(html, "modal-close")
}

pub fn renders_close_icon_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Contains close icon (×)
  assert_contains(html, "\u{2715}")
}

pub fn view_with_class_uses_custom_class_test() {
  // Given/When: Render with custom class
  let html =
    modal_close_button.view_with_class("my-custom-close", Nil)
    |> element.to_string()

  // Then: Uses custom class
  assert_contains(html, "my-custom-close")
}
