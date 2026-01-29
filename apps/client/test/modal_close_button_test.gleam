//// Tests for modal_close_button UI component.

import gleam/string
import gleeunit/should
import lustre/element
import scrumbringer_client/ui/modal_close_button

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
  html |> string.contains("aria-label") |> should.be_true()
  html |> string.contains("Close") |> should.be_true()
}

pub fn renders_close_button_with_correct_class_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Has expected CSS classes
  html |> string.contains("btn-icon") |> should.be_true()
  html |> string.contains("modal-close") |> should.be_true()
}

pub fn renders_close_icon_test() {
  // Given/When: Render close button
  let html = render_to_string()

  // Then: Contains close icon (×)
  html |> string.contains("\u{2715}") |> should.be_true()
}

pub fn view_with_class_uses_custom_class_test() {
  // Given/When: Render with custom class
  let html =
    modal_close_button.view_with_class("my-custom-close", Nil)
    |> element.to_string()

  // Then: Uses custom class
  html |> string.contains("my-custom-close") |> should.be_true()
}
