//// Tests for text utilities.

import scrumbringer_client/utils/text.{truncate, truncate_with_info}

// =============================================================================
// truncate tests
// =============================================================================

pub fn truncate_short_text_unchanged_test() {
  let assert "Hello" = truncate("Hello", 10)
}

pub fn truncate_exact_length_unchanged_test() {
  let assert "Hello" = truncate("Hello", 5)
}

pub fn truncate_long_text_adds_ellipsis_test() {
  let assert "Hello..." = truncate("Hello World", 5)
}

pub fn truncate_empty_string_test() {
  let assert "" = truncate("", 10)
}

pub fn truncate_single_char_test() {
  let assert "A" = truncate("A", 1)
}

pub fn truncate_to_zero_test() {
  let assert "..." = truncate("Hello", 0)
}

// =============================================================================
// truncate_with_info tests
// =============================================================================

pub fn truncate_with_info_short_text_test() {
  let assert #("Hello", False) = truncate_with_info("Hello", 10)
}

pub fn truncate_with_info_long_text_test() {
  let assert #("Hello...", True) = truncate_with_info("Hello World", 5)
}

pub fn truncate_with_info_exact_length_test() {
  let assert #("Hello", False) = truncate_with_info("Hello", 5)
}
