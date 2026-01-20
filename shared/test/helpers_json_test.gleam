//// Unit tests for helpers/json module.

import gleam/json
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import helpers/json as json_helpers

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// option_to_json tests
// =============================================================================

pub fn option_to_json_returns_null_for_none_test() {
  json_helpers.option_to_json(None, json.int)
  |> json.to_string()
  |> should.equal("null")
}

pub fn option_to_json_applies_encoder_for_some_test() {
  json_helpers.option_to_json(Some(42), json.int)
  |> json.to_string()
  |> should.equal("42")
}

// =============================================================================
// option_int_json tests
// =============================================================================

pub fn option_int_json_returns_null_for_none_test() {
  json_helpers.option_int_json(None)
  |> json.to_string()
  |> should.equal("null")
}

pub fn option_int_json_returns_int_for_some_test() {
  json_helpers.option_int_json(Some(42))
  |> json.to_string()
  |> should.equal("42")
}

pub fn option_int_json_handles_zero_test() {
  json_helpers.option_int_json(Some(0))
  |> json.to_string()
  |> should.equal("0")
}

pub fn option_int_json_handles_negative_test() {
  json_helpers.option_int_json(Some(-5))
  |> json.to_string()
  |> should.equal("-5")
}

// =============================================================================
// option_string_json tests
// =============================================================================

pub fn option_string_json_returns_null_for_none_test() {
  json_helpers.option_string_json(None)
  |> json.to_string()
  |> should.equal("null")
}

pub fn option_string_json_returns_string_for_some_test() {
  json_helpers.option_string_json(Some("hello"))
  |> json.to_string()
  |> should.equal("\"hello\"")
}

pub fn option_string_json_handles_empty_string_test() {
  json_helpers.option_string_json(Some(""))
  |> json.to_string()
  |> should.equal("\"\"")
}

// =============================================================================
// option_float_json tests
// =============================================================================

pub fn option_float_json_returns_null_for_none_test() {
  json_helpers.option_float_json(None)
  |> json.to_string()
  |> should.equal("null")
}

pub fn option_float_json_returns_float_for_some_test() {
  json_helpers.option_float_json(Some(3.14))
  |> json.to_string()
  |> should.equal("3.14")
}

// =============================================================================
// option_bool_json tests
// =============================================================================

pub fn option_bool_json_returns_null_for_none_test() {
  json_helpers.option_bool_json(None)
  |> json.to_string()
  |> should.equal("null")
}

pub fn option_bool_json_returns_bool_for_some_test() {
  json_helpers.option_bool_json(Some(True))
  |> json.to_string()
  |> should.equal("true")
}
