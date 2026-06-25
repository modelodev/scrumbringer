//// Project JSON decoders.

import gleam/dynamic/decode

import domain/project.{
  type Project, type ProjectDepthName, type ProjectMember, Project,
  ProjectDepthName, ProjectMember,
}
import domain/project/settings
import domain/project_role/project_role_codec

pub fn default_card_depth_names() -> List(ProjectDepthName) {
  settings.default_card_depth_names()
}

fn project_depth_name_decoder() -> decode.Decoder(ProjectDepthName) {
  use depth <- decode.field("depth", decode.int)
  use singular_name <- decode.field("singular_name", decode.string)
  use plural_name <- decode.field("plural_name", decode.string)
  decode.success(ProjectDepthName(
    depth: depth,
    singular_name: singular_name,
    plural_name: plural_name,
  ))
}

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
  use card_depth_names <- decode.optional_field(
    "card_depth_names",
    default_card_depth_names(),
    decode.list(project_depth_name_decoder()),
  )
  use healthy_pool_limit <- decode.optional_field(
    "healthy_pool_limit",
    20,
    decode.int,
  )
  decode.success(Project(
    id: id,
    name: name,
    my_role: my_role,
    created_at: created_at,
    members_count: members_count,
    card_depth_names: card_depth_names,
    healthy_pool_limit: healthy_pool_limit,
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
    card_depth_names: default_card_depth_names(),
    healthy_pool_limit: 20,
  ))
}
