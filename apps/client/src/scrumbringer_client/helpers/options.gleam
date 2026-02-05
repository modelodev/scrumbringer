//// Helpers for Option conversions.

import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

/// Convert empty string to None, non-empty to Some.
pub fn empty_to_opt(value: String) -> Option(String) {
  case string.trim(value) == "" {
    True -> None
    False -> Some(value)
  }
}

/// Convert string to Option(Int), empty string becomes None.
pub fn empty_to_int_opt(value: String) -> Option(Int) {
  let trimmed = string.trim(value)

  case trimmed == "" {
    True -> None
    False ->
      case int.parse(trimmed) {
        Ok(i) -> Some(i)
        Error(_) -> None
      }
  }
}
