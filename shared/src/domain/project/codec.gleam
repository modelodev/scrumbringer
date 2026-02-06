//// Project JSON decoders.

import gleam/dynamic/decode

import domain/project.{type Project, type ProjectMember, Project, ProjectMember}
import domain/project_role/codec as project_role_codec

/// Decoder for Project with my_role field.
pub fn project_decoder() -> decode.Decoder(Project) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use my_role <- decode.field(
    "my_role",
    project_role_codec.project_role_decoder(),
  )
  use created_at <- decode.field("created_at", decode.string)
  use members_count <- decode.field("members_count", decode.int)
  decode.success(Project(
    id: id,
    name: name,
    my_role: my_role,
    created_at: created_at,
    members_count: members_count,
  ))
}

/// Decoder for ProjectMember.
pub fn project_member_decoder() -> decode.Decoder(ProjectMember) {
  use user_id <- decode.field("user_id", decode.int)
  use role <- decode.field("role", project_role_codec.project_role_decoder())
  use created_at <- decode.field("created_at", decode.string)
  use claimed_count <- decode.field("claimed_count", decode.int)
  decode.success(ProjectMember(
    user_id: user_id,
    role: role,
    created_at: created_at,
    claimed_count: claimed_count,
  ))
}

/// Decoder for Project references returned from org user endpoints.
pub fn user_project_decoder() -> decode.Decoder(Project) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use my_role <- decode.field("role", project_role_codec.project_role_decoder())
  decode.success(Project(
    id: id,
    name: name,
    my_role: my_role,
    created_at: "",
    members_count: 0,
  ))
}
