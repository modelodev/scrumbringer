//// JSON helper functions for optional values.
////
//// This module provides utilities for converting Option types to JSON,
//// centralizing the common pattern of encoding None as null and Some(value)
//// as the encoded value.
////
//// ## Usage
////
//// ```gleam
//// import helpers/json as json_helpers
////
//// json_helpers.option_int_json(Some(42))     // json.int(42)
//// json_helpers.option_int_json(None)         // json.null()
//// json_helpers.option_string_json(Some("x")) // json.string("x")
//// ```

import gleam/json
import gleam/option.{type Option, None, Some}

// =============================================================================
// Option to JSON Converters
// =============================================================================

/// Convert any optional value to JSON using a provided encoder.
///
/// This is the generic version that works with any type.
///
/// ## Example
///
/// ```gleam
/// option_to_json(Some(42), json.int)       // json.int(42)
/// option_to_json(None, json.int)           // json.null()
/// option_to_json(Some("hi"), json.string)  // json.string("hi")
/// ```
pub fn option_to_json(
  value: Option(a),
  encoder: fn(a) -> json.Json,
) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> encoder(v)
  }
}

/// Convert optional Int to JSON (null if None).
///
/// ## Example
///
/// ```gleam
/// option_int_json(Some(42))  // json.int(42)
/// option_int_json(None)      // json.null()
/// ```
pub fn option_int_json(value: Option(Int)) -> json.Json {
  option_to_json(value, json.int)
}

/// Convert optional String to JSON (null if None).
///
/// ## Example
///
/// ```gleam
/// option_string_json(Some("hello"))  // json.string("hello")
/// option_string_json(None)           // json.null()
/// ```
pub fn option_string_json(value: Option(String)) -> json.Json {
  option_to_json(value, json.string)
}

/// Convert optional Float to JSON (null if None).
///
/// ## Example
///
/// ```gleam
/// option_float_json(Some(3.14))  // json.float(3.14)
/// option_float_json(None)        // json.null()
/// ```
pub fn option_float_json(value: Option(Float)) -> json.Json {
  option_to_json(value, json.float)
}

/// Convert optional Bool to JSON (null if None).
///
/// ## Example
///
/// ```gleam
/// option_bool_json(Some(True))  // json.bool(True)
/// option_bool_json(None)        // json.null()
/// ```
pub fn option_bool_json(value: Option(Bool)) -> json.Json {
  option_to_json(value, json.bool)
}
