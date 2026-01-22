//// Text utilities for Scrumbringer UI.
////
//// Provides common text manipulation functions used across the application.

import gleam/string

/// Truncate a string to a maximum length, adding "..." if truncated.
///
/// ## Example
///
/// ```gleam
/// truncate("Hello World", 5)  // "Hello..."
/// truncate("Hi", 10)          // "Hi"
/// ```
pub fn truncate(s: String, max_len: Int) -> String {
  case string.length(s) > max_len {
    True -> string.slice(s, 0, max_len) <> "..."
    False -> s
  }
}

/// Truncate a string and return both truncated text and whether it was truncated.
///
/// Useful for conditionally showing tooltips only when text is truncated.
///
/// ## Example
///
/// ```gleam
/// truncate_with_info("Hello World", 5)  // #("Hello...", True)
/// truncate_with_info("Hi", 10)          // #("Hi", False)
/// ```
pub fn truncate_with_info(s: String, max_len: Int) -> #(String, Bool) {
  case string.length(s) > max_len {
    True -> #(string.slice(s, 0, max_len) <> "...", True)
    False -> #(s, False)
  }
}
