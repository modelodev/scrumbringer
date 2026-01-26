//// Shared helpers for CRUD dialog custom elements.
////
//// Centralizes common attribute decoding and small utilities.

import gleam/int
import gleam/option.{type Option}
import gleam/result

import scrumbringer_client/i18n/locale.{type Locale, deserialize}

/// Decodes locale.
///
/// Example:
///   decode_locale(...)
pub fn decode_locale(
  value: String,
  to_msg: fn(Locale) -> msg,
) -> Result(msg, Nil) {
  Ok(to_msg(deserialize(value)))
}

/// Decodes int attribute.
///
/// Example:
///   decode_int_attribute(...)
pub fn decode_int_attribute(
  value: String,
  to_msg: fn(Int) -> msg,
) -> Result(msg, Nil) {
  int.parse(value)
  |> result.map(to_msg)
  |> result.replace_error(Nil)
}

/// Decodes optional int attribute.
///
/// Example:
///   decode_optional_int_attribute(...)
pub fn decode_optional_int_attribute(
  value: String,
  to_msg: fn(Option(Int)) -> msg,
) -> Result(msg, Nil) {
  case value {
    "" | "null" | "undefined" -> Ok(to_msg(option.None))
    _ ->
      int.parse(value)
      |> result.map(fn(id) { to_msg(option.Some(id)) })
      |> result.replace_error(Nil)
  }
}

/// Decodes create mode.
///
/// Example:
///   decode_create_mode(...)
pub fn decode_create_mode(
  value: String,
  create_mode: mode,
  to_msg: fn(mode) -> msg,
) -> Result(msg, Nil) {
  case value {
    "create" -> Ok(to_msg(create_mode))
    _ -> Error(Nil)
  }
}
