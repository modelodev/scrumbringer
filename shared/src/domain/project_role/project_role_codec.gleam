//// Project role JSON decoders.

import gleam/dynamic/decode

import domain/project_role

/// Decoder for ProjectRole.
pub fn project_role_decoder() -> decode.Decoder(project_role.ProjectRole) {
  use role_string <- decode.then(decode.string)
  case project_role.parse(role_string) {
    Ok(role) -> decode.success(role)
    Error(_) -> decode.failure(project_role.Manager, "ProjectRole")
  }
}
