//// Option helper functions for database mappers.
////
//// This module provides utilities for converting database values (where NULL
//// is represented as 0 for integers or "" for strings) into proper Option types.
////
//// ## Important
////
//// These functions treat `0` and `""` as `None`. This is intentional for
//// database FK columns where 0 means "no reference", but may not be correct
//// for columns where 0 or "" are legitimate values.
////
//// ## Usage
////
//// ```gleam
//// import helpers/option as option_helpers
////
//// option_helpers.int_to_option(0)     // None
//// option_helpers.int_to_option(42)    // Some(42)
//// option_helpers.string_to_option("") // None
//// option_helpers.string_to_option("x") // Some("x")
//// ```

import gleam/option.{type Option, None, Some}

// =============================================================================
// Database Value to Option Converters
// =============================================================================

/// Convert an integer to Option, treating 0 as None.
///
/// This is useful for database columns where 0 represents "no value" or
/// "no foreign key reference".
///
/// ## Warning
///
/// This function treats 0 as None, which may not be correct for columns
/// where 0 is a valid value. Use with caution.
///
/// ## Example
///
/// ```gleam
/// int_to_option(0)   // None
/// int_to_option(42)  // Some(42)
/// int_to_option(-1)  // Some(-1)
/// ```
pub fn int_to_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    n -> Some(n)
  }
}

/// Convert a string to Option, treating empty string as None.
///
/// This is useful for database columns where "" represents "no value".
///
/// ## Warning
///
/// This function treats "" as None, which may not be correct for columns
/// where empty string is a valid value. Use with caution.
///
/// ## Example
///
/// ```gleam
/// string_to_option("")      // None
/// string_to_option("hello") // Some("hello")
/// ```
pub fn string_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    s -> Some(s)
  }
}

/// Convert an optional value, using a custom "null" value.
///
/// This is a more flexible version that lets you specify what value
/// represents "no value".
///
/// ## Example
///
/// ```gleam
/// value_to_option(-1, -1)     // None
/// value_to_option(42, -1)     // Some(42)
/// value_to_option("N/A", "N/A") // None
/// ```
pub fn value_to_option(value: a, null_value: a) -> Option(a) {
  case value == null_value {
    True -> None
    False -> Some(value)
  }
}
