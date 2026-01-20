//// Unit tests for helpers/option module.

import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import helpers/option as option_helpers

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// int_to_option tests
// =============================================================================

pub fn int_to_option_returns_none_for_zero_test() {
  option_helpers.int_to_option(0)
  |> should.equal(None)
}

pub fn int_to_option_returns_some_for_positive_test() {
  option_helpers.int_to_option(42)
  |> should.equal(Some(42))
}

pub fn int_to_option_returns_some_for_negative_test() {
  option_helpers.int_to_option(-5)
  |> should.equal(Some(-5))
}

pub fn int_to_option_returns_some_for_one_test() {
  option_helpers.int_to_option(1)
  |> should.equal(Some(1))
}

// =============================================================================
// string_to_option tests
// =============================================================================

pub fn string_to_option_returns_none_for_empty_test() {
  option_helpers.string_to_option("")
  |> should.equal(None)
}

pub fn string_to_option_returns_some_for_non_empty_test() {
  option_helpers.string_to_option("hello")
  |> should.equal(Some("hello"))
}

pub fn string_to_option_returns_some_for_whitespace_test() {
  option_helpers.string_to_option(" ")
  |> should.equal(Some(" "))
}

// =============================================================================
// value_to_option tests
// =============================================================================

pub fn value_to_option_returns_none_for_null_value_test() {
  option_helpers.value_to_option(-1, -1)
  |> should.equal(None)
}

pub fn value_to_option_returns_some_for_different_value_test() {
  option_helpers.value_to_option(42, -1)
  |> should.equal(Some(42))
}

pub fn value_to_option_works_with_strings_test() {
  option_helpers.value_to_option("N/A", "N/A")
  |> should.equal(None)
}
