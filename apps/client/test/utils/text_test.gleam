//// Tests for text utilities.

import gleeunit/should

import scrumbringer_client/utils/text.{truncate, truncate_with_info}

// =============================================================================
// truncate tests
// =============================================================================

pub fn truncate_short_text_unchanged_test() {
  truncate("Hello", 10)
  |> should.equal("Hello")
}

pub fn truncate_exact_length_unchanged_test() {
  truncate("Hello", 5)
  |> should.equal("Hello")
}

pub fn truncate_long_text_adds_ellipsis_test() {
  truncate("Hello World", 5)
  |> should.equal("Hello...")
}

pub fn truncate_empty_string_test() {
  truncate("", 10)
  |> should.equal("")
}

pub fn truncate_single_char_test() {
  truncate("A", 1)
  |> should.equal("A")
}

pub fn truncate_to_zero_test() {
  truncate("Hello", 0)
  |> should.equal("...")
}

// =============================================================================
// truncate_with_info tests
// =============================================================================

pub fn truncate_with_info_short_text_test() {
  truncate_with_info("Hello", 10)
  |> should.equal(#("Hello", False))
}

pub fn truncate_with_info_long_text_test() {
  truncate_with_info("Hello World", 5)
  |> should.equal(#("Hello...", True))
}

pub fn truncate_with_info_exact_length_test() {
  truncate_with_info("Hello", 5)
  |> should.equal(#("Hello", False))
}
