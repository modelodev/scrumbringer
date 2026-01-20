//// Unit tests for JSON presenter functions.
////
//// Tests option_int_json and option_string_json helper functions from
//// the presenters module.

import gleam/json
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import scrumbringer_server/http/tasks/presenters

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC1: option_int_json returns null for None
// =============================================================================

pub fn option_int_json_returns_null_for_none_test() {
  // Given: None value for optional Int
  let value = None

  // When: Convert to JSON
  let result = presenters.option_int_json(value)

  // Then: Returns json.null()
  result
  |> json.to_string()
  |> should.equal("null")
}

// =============================================================================
// AC2: option_int_json returns int for Some
// =============================================================================

pub fn option_int_json_returns_int_for_some_test() {
  // Given: Some(42) value
  let value = Some(42)

  // When: Convert to JSON
  let result = presenters.option_int_json(value)

  // Then: Returns json.int(42)
  result
  |> json.to_string()
  |> should.equal("42")
}

// =============================================================================
// AC3: option_string_json returns null for None
// =============================================================================

pub fn option_string_json_returns_null_for_none_test() {
  // Given: None value for optional String
  let value = None

  // When: Convert to JSON
  let result = presenters.option_string_json(value)

  // Then: Returns json.null()
  result
  |> json.to_string()
  |> should.equal("null")
}

// =============================================================================
// AC4: option_string_json returns string for Some
// =============================================================================

pub fn option_string_json_returns_string_for_some_test() {
  // Given: Some("hello") value
  let value = Some("hello")

  // When: Convert to JSON
  let result = presenters.option_string_json(value)

  // Then: Returns json.string("hello")
  result
  |> json.to_string()
  |> should.equal("\"hello\"")
}
