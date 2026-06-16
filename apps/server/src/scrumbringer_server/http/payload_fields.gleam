//// Shared decoders for HTTP payload field conventions.

import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}

pub fn optional_active_flag_decoder() -> decode.Decoder(Option(Bool)) {
  use active <- decode.then(decode.optional(decode.int))
  case active {
    None -> decode.success(None)
    Some(0) -> decode.success(Some(False))
    Some(1) -> decode.success(Some(True))
    Some(_) -> decode.failure(None, "ActiveFlag")
  }
}
