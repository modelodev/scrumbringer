//// Helpers for Option conversions.

import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

/// Convert user search input to a normalized optional query.
pub fn search_to_opt(value: String) -> Option(String) {
  let trimmed = string.trim(value)

  case trimmed {
    "" -> None
    _ -> Some(trimmed)
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
