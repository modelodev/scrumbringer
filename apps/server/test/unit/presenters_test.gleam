//// Unit tests for JSON presenter functions.
////
//// Tests shared optional JSON helpers and presenter-specific fallback logic.

import gleam/json
import gleam/option.{None, Some}
import gleeunit
import helpers/json as json_helpers
import scrumbringer_server/http/metrics_presenters
import support/assertions as expect

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
  let result = json_helpers.option_int_json(value)

  // Then: Returns json.null()
  result
  |> json.to_string()
  |> expect.equal("null")
}

// =============================================================================
// AC2: option_int_json returns int for Some
// =============================================================================

pub fn option_int_json_returns_int_for_some_test() {
  // Given: Some(42) value
  let value = Some(42)

  // When: Convert to JSON
  let result = json_helpers.option_int_json(value)

  // Then: Returns json.int(42)
  result
  |> json.to_string()
  |> expect.equal("42")
}

// =============================================================================
// AC3: option_string_json returns null for None
// =============================================================================

pub fn option_string_json_returns_null_for_none_test() {
  // Given: None value for optional String
  let value = None

  // When: Convert to JSON
  let result = json_helpers.option_string_json(value)

  // Then: Returns json.null()
  result
  |> json.to_string()
  |> expect.equal("null")
}

// =============================================================================
// AC4: option_string_json returns string for Some
// =============================================================================

pub fn option_string_json_returns_string_for_some_test() {
  // Given: Some("hello") value
  let value = Some("hello")

  // When: Convert to JSON
  let result = json_helpers.option_string_json(value)

  // Then: Returns json.string("hello")
  result
  |> json.to_string()
  |> expect.equal("\"hello\"")
}

pub fn workflow_name_or_default_preserves_existing_name_test() {
  metrics_presenters.workflow_name_or_default(Some("Review flow"))
  |> expect.equal("Review flow")
}

pub fn workflow_name_or_default_uses_api_fallback_test() {
  metrics_presenters.workflow_name_or_default(None)
  |> expect.equal("sin_workflow")
}
