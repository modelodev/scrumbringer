//// Helpers for validating primitive values read from repository.
////
//// Domain mappers should stay explicit about which fields they map. These
//// helpers only centralise the common "parse persisted string or fail as an
//// unexpected data shape" pattern.

import gleam/dynamic/decode
import pog
import scrumbringer_server/use_case/service_error.{type ServiceError, Unexpected}

pub fn required(
  value: String,
  parse: fn(String) -> Result(parsed, error),
  message: String,
) -> Result(parsed, ServiceError) {
  case parse(value) {
    Ok(parsed) -> Ok(parsed)
    Error(_) -> Error(Unexpected(message <> ": " <> value))
  }
}

pub fn returned_row(
  rows: List(row),
  operation: String,
) -> Result(row, ServiceError) {
  case rows {
    [row, ..] -> Ok(row)
    [] -> Error(Unexpected(operation <> " returned no row"))
  }
}

pub fn query_row(rows: List(row)) -> Result(row, pog.QueryError) {
  case rows {
    [row, ..] -> Ok(row)
    [] -> Error(pog.UnexpectedResultType([]))
  }
}

pub fn int_decoder() -> decode.Decoder(Int) {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}

pub fn bool_decoder() -> decode.Decoder(Bool) {
  use value <- decode.field(0, decode.bool)
  decode.success(value)
}

pub fn string_decoder() -> decode.Decoder(String) {
  use value <- decode.field(0, decode.string)
  decode.success(value)
}
