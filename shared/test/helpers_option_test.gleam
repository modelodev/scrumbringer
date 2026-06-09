//// Unit tests for helpers/option module.

import gleam/option.{None, Some}
import gleeunit
import helpers/option as option_helpers

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// int_to_option tests
// =============================================================================

pub fn int_to_option_returns_none_for_zero_test() {
  let assert None = option_helpers.int_to_option(0)
}

pub fn int_to_option_returns_some_for_positive_test() {
  let assert Some(42) = option_helpers.int_to_option(42)
}

pub fn int_to_option_returns_some_for_negative_test() {
  let assert Some(-5) = option_helpers.int_to_option(-5)
}

pub fn int_to_option_returns_some_for_one_test() {
  let assert Some(1) = option_helpers.int_to_option(1)
}

// =============================================================================
// string_to_option tests
// =============================================================================

pub fn string_to_option_returns_none_for_empty_test() {
  let assert None = option_helpers.string_to_option("")
}

pub fn string_to_option_returns_some_for_non_empty_test() {
  let assert Some("hello") = option_helpers.string_to_option("hello")
}

pub fn string_to_option_returns_some_for_whitespace_test() {
  let assert Some(" ") = option_helpers.string_to_option(" ")
}

// =============================================================================
// value_to_option tests
// =============================================================================

pub fn value_to_option_returns_none_for_null_value_test() {
  let assert None = option_helpers.value_to_option(-1, -1)
}

pub fn value_to_option_returns_some_for_different_value_test() {
  let assert Some(42) = option_helpers.value_to_option(42, -1)
}

pub fn value_to_option_works_with_strings_test() {
  let assert None = option_helpers.value_to_option("N/A", "N/A")
}
