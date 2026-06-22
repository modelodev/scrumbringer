//// Organization JSON decoders.

import gleam/dynamic/decode
import gleam/option

import domain/org.{
  type InviteLink, type InviteLinkState, type OrgInvite, type OrgUser, Active,
  InviteLink, OrgInvite, OrgUser, parse_invite_link_state,
}
import domain/org_role/org_role_codec

/// Decoder for OrgUser.
pub fn org_user_decoder() -> decode.Decoder(OrgUser) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use org_role_value <- decode.field(
    "org_role",
    org_role_codec.org_role_decoder(),
  )
  use created_at <- decode.field("created_at", decode.string)
  decode.success(OrgUser(
    id: id,
    email: email,
    org_role: org_role_value,
    created_at: created_at,
  ))
}

/// Decoder for OrgInvite.
pub fn invite_decoder() -> decode.Decoder(OrgInvite) {
  use code <- decode.field("code", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use expires_at <- decode.field("expires_at", decode.string)
  decode.success(OrgInvite(
    code: code,
    created_at: created_at,
    expires_at: expires_at,
  ))
}

/// Decoder for InviteLink.
pub fn invite_link_decoder() -> decode.Decoder(InviteLink) {
  use email <- decode.field("email", decode.string)
  use token <- decode.field("token", decode.string)
  use url_path <- decode.field("url_path", decode.string)
  use state <- decode.field("state", invite_link_state_decoder())
  use created_at <- decode.field("created_at", decode.string)

  use used_at <- decode.optional_field(
    "used_at",
    option.None,
    decode.optional(decode.string),
  )

  use invalidated_at <- decode.optional_field(
    "invalidated_at",
    option.None,
    decode.optional(decode.string),
  )

  decode.success(InviteLink(
    email: email,
    token: token,
    url_path: url_path,
    state: state,
    created_at: created_at,
    used_at: used_at,
    invalidated_at: invalidated_at,
  ))
}

fn invite_link_state_decoder() -> decode.Decoder(InviteLinkState) {
  use raw <- decode.then(decode.string)
  case parse_invite_link_state(raw) {
    Ok(state) -> decode.success(state)
    Error(_) -> decode.failure(Active, "InviteLinkState")
  }
}
