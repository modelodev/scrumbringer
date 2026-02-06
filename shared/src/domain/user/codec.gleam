//// User JSON decoders.

import gleam/dynamic/decode

import domain/org_role/codec as org_role_codec
import domain/user.{type User, User}

/// Decoder for User.
pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use org_id <- decode.field("org_id", decode.int)
  use org_role_value <- decode.field(
    "org_role",
    org_role_codec.org_role_decoder(),
  )
  use created_at <- decode.field("created_at", decode.string)

  decode.success(User(
    id: id,
    email: email,
    org_id: org_id,
    org_role: org_role_value,
    created_at: created_at,
  ))
}
