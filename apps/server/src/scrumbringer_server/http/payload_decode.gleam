//// Shared helpers for HTTP payload decoding.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

pub fn run(
  data: Dynamic,
  decoder: decode.Decoder(payload),
) -> Result(payload, Nil) {
  run_error(data, decoder, Nil)
}

pub fn run_error(
  data: Dynamic,
  decoder: decode.Decoder(payload),
  error: error,
) -> Result(payload, error) {
  decode.run(data, decoder)
  |> result.map_error(fn(_) { error })
}
