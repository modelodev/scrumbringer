//// Capability JSON decoders.

import gleam/dynamic/decode

import domain/capability.{type Capability, Capability}

/// Decoder for Capability.
pub fn capability_decoder() -> decode.Decoder(Capability) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(Capability(id: id, name: name))
}
