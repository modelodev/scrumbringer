//// Shared DOM event decoders.
////
//// Centralizes small decoder helpers used across views.

import gleam/dynamic/decode

pub fn mouse_client_position(to_msg: fn(Int, Int) -> msg) -> decode.Decoder(msg) {
  use x <- decode.field("clientX", decode.int)
  use y <- decode.field("clientY", decode.int)
  decode.success(to_msg(x, y))
}

pub fn mouse_offset(to_msg: fn(Int, Int) -> msg) -> decode.Decoder(msg) {
  use x <- decode.field("offsetX", decode.int)
  use y <- decode.field("offsetY", decode.int)
  decode.success(to_msg(x, y))
}
