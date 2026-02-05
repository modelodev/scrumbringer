//// Validation helpers.

import gleam/list
import gleam/string

import scrumbringer_client/client_state.{type Model}
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text

pub opaque type NonEmptyString {
  NonEmptyString(String)
}

/// Provides non empty string value.
pub fn non_empty_string_value(value: NonEmptyString) -> String {
  let NonEmptyString(inner) = value
  inner
}

/// Validate that a string is not empty after trimming.
pub fn validate_required_string(
  model: Model,
  value: String,
  error_text: i18n_text.Text,
) -> Result(NonEmptyString, String) {
  let trimmed = string.trim(value)
  case trimmed == "" {
    True -> Error(helpers_i18n.i18n_t(model, error_text))
    False -> Ok(NonEmptyString(trimmed))
  }
}

/// Validate that a string is not empty without trimming.
pub fn validate_required_string_raw(
  model: Model,
  value: String,
  error_text: i18n_text.Text,
) -> Result(NonEmptyString, String) {
  case value == "" {
    True -> Error(helpers_i18n.i18n_t(model, error_text))
    False -> Ok(NonEmptyString(value))
  }
}

/// Validate multiple required fields and return first error.
pub fn validate_required_fields(
  model: Model,
  fields: List(#(String, i18n_text.Text)),
) -> Result(List(NonEmptyString), String) {
  fields
  |> list.try_map(fn(field) {
    let #(value, error_text) = field
    validate_required_string(model, value, error_text)
  })
}
