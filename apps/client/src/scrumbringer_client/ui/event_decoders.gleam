//// Shared DOM event decoders.
////
//// Centralizes small decoder helpers used across views.

import gleam/dynamic/decode

/// Provides mouse client position.
///
/// Example:
///   mouse_client_position(...)
pub fn mouse_client_position(to_msg: fn(Int, Int) -> msg) -> decode.Decoder(msg) {
  use x <- decode.field("clientX", decode.int)
  use y <- decode.field("clientY", decode.int)
  decode.success(to_msg(x, y))
}

/// Provides mouse offset.
///
/// Example:
///   mouse_offset(...)
pub fn mouse_offset(to_msg: fn(Int, Int) -> msg) -> decode.Decoder(msg) {
  use x <- decode.field("offsetX", decode.int)
  use y <- decode.field("offsetY", decode.int)
  decode.success(to_msg(x, y))
}

/// Provides touch client position using the first touch point.
///
/// Example:
///   touch_client_position(...)
pub fn touch_client_position(to_msg: fn(Int, Int) -> msg) -> decode.Decoder(msg) {
  decode.at(["touches", "0"], {
    use x <- decode.field("clientX", decode.int)
    use y <- decode.field("clientY", decode.int)
    decode.success(to_msg(x, y))
  })
}

/// Provides a constant message decoder.
pub fn message(msg: msg) -> decode.Decoder(msg) {
  decode.success(msg)
}

/// Provides a decoder for CustomEvent detail payloads.
///
/// Example:
///   custom_detail(user_decoder)
pub fn custom_detail(
  decoder: decode.Decoder(a),
  next: fn(a) -> decode.Decoder(b),
) -> decode.Decoder(b) {
  decode.field("detail", decoder, next)
}
