//// API error JSON decoders.

import gleam/dynamic/decode

import domain/api_error.{type ApiError, ApiError}

/// Decoder for ApiError using HTTP status.
pub fn api_error_decoder(status: Int) -> decode.Decoder(ApiError) {
  let error_inner = {
    use code <- decode.field("code", decode.string)
    use message <- decode.field("message", decode.string)
    decode.success(#(code, message))
  }

  decode.field("error", error_inner, fn(inner) {
    let #(code, message) = inner
    decode.success(ApiError(status: status, code: code, message: message))
  })
}
