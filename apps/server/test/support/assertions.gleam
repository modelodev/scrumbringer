//// Test assertion helpers based on Gleam's `let assert`.
////
//// Provides a small replacement for deprecated pipeline-style assertions.
//// Keep these helpers intentionally boring: they should make tests shorter
//// without hiding domain-specific expectations.

import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, Some}
import gleam/string
import wisp.{type Response}
import wisp/simulate

/// Assert that two values are equal.
///
/// Example:
/// ```gleam
/// actual |> equal(expected)
/// ```
pub fn equal(actual: a, expected: a) -> Nil {
  case actual == expected {
    True -> Nil
    False ->
      panic as {
        "expected "
        <> string.inspect(expected)
        <> ", got "
        <> string.inspect(actual)
      }
  }
}

/// Assert that an HTTP response has the expected status.
pub fn expect_status(response: Response, expected: Int) -> Nil {
  case response.status == expected {
    True -> Nil
    False ->
      panic as {
        "expected HTTP status "
        <> string.inspect(expected)
        <> ", got "
        <> string.inspect(response.status)
        <> ", body: "
        <> simulate.read_body(response)
      }
  }
}

/// Assert that an integer JSON field at `path` has the expected value.
pub fn expect_json_field_int(
  body: String,
  path: List(String),
  expected: Int,
) -> Nil {
  let dynamic = parse_json_body(body)
  case decode.run(dynamic, int_at_path(path)) {
    Ok(value) -> equal(value, expected)
    Error(errors) ->
      panic as {
        "expected JSON int at "
        <> string.inspect(path)
        <> ", decode errors: "
        <> string.inspect(errors)
      }
  }
}

/// Assert that a standard API error body contains the expected error code.
pub fn expect_json_contains_code(body: String, code: String) -> Nil {
  let path = ["error", "code"]
  let dynamic = parse_json_body(body)
  case decode.run(dynamic, string_at_path(path)) {
    Ok(value) -> equal(value, code)
    Error(errors) ->
      panic as {
        "expected JSON error code at "
        <> string.inspect(path)
        <> ", decode errors: "
        <> string.inspect(errors)
      }
  }
}

/// Assert that two values are not equal.
///
/// Example:
/// ```gleam
/// actual |> not_equal(unexpected)
/// ```
pub fn not_equal(actual: a, expected: a) -> Nil {
  case actual == expected {
    False -> Nil
    True ->
      panic as { "expected value different from " <> string.inspect(expected) }
  }
}

/// Assert that a boolean value is true.
///
/// Example:
/// ```gleam
/// value |> is_true
/// ```
pub fn is_true(value: Bool) -> Nil {
  let assert True = value
  Nil
}

/// Assert that a boolean value is false.
///
/// Example:
/// ```gleam
/// value |> is_false
/// ```
pub fn is_false(value: Bool) -> Nil {
  let assert False = value
  Nil
}

/// Assert that a result is `Ok` and return its value.
///
/// Example:
/// ```gleam
/// let value = result |> ok
/// ```
pub fn ok(result: Result(a, e)) -> a {
  let assert Ok(value) = result
  value
}

/// Assert that a result is `Error` and return its value.
///
/// Example:
/// ```gleam
/// let error = result |> error
/// ```
pub fn error(result: Result(a, e)) -> e {
  let assert Error(value) = result
  value
}

/// Assert that an option is `Some` and return its value.
///
/// Example:
/// ```gleam
/// let value = option |> some
/// ```
pub fn some(option: Option(a)) -> a {
  let assert Some(value) = option
  value
}

/// Fail the current test.
///
/// Example:
/// ```gleam
/// fail()
/// ```
pub fn fail() -> Nil {
  panic as "test assertion failed"
}

fn int_at_path(path: List(String)) -> decode.Decoder(Int) {
  decode.at(path, decode.int)
}

fn string_at_path(path: List(String)) -> decode.Decoder(String) {
  decode.at(path, decode.string)
}

fn parse_json_body(body: String) -> decode.Dynamic {
  case json.parse(body, decode.dynamic) {
    Ok(dynamic) -> dynamic
    Error(errors) ->
      panic as {
        "expected valid JSON body, got "
        <> string.inspect(body)
        <> "; parse errors: "
        <> string.inspect(errors)
      }
  }
}
