//// Org role JSON decoders.

import gleam/dynamic/decode

import domain/org_role

/// Decoder for OrgRole.
pub fn org_role_decoder() -> decode.Decoder(org_role.OrgRole) {
  use role_string <- decode.then(decode.string)
  case org_role.parse(role_string) {
    Ok(role) -> decode.success(role)
    Error(_) -> decode.failure(org_role.Member, "OrgRole")
  }
}
