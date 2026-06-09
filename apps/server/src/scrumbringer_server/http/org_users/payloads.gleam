//// JSON payload decoders for organization user endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

import domain/org_role.{type OrgRole}
import domain/org_role/codec as org_role_codec
import domain/project_role.{type ProjectRole, Member}
import domain/project_role/codec as project_role_codec

pub type OrgRolePayload {
  OrgRolePayload(org_role: OrgRole)
}

pub type UserProjectPayload {
  UserProjectPayload(project_id: Int, role: ProjectRole)
}

pub type RolePayload {
  RolePayload(role: ProjectRole)
}

pub fn decode_org_role(data: Dynamic) -> Result(OrgRolePayload, Nil) {
  let decoder = {
    use role <- decode.field("org_role", org_role_codec.org_role_decoder())
    decode.success(OrgRolePayload(org_role: role))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_user_project(data: Dynamic) -> Result(UserProjectPayload, Nil) {
  let decoder = {
    use project_id <- decode.field("project_id", decode.int)
    use role <- decode.optional_field(
      "role",
      Member,
      project_role_codec.project_role_decoder(),
    )
    decode.success(UserProjectPayload(project_id: project_id, role: role))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_role(data: Dynamic) -> Result(RolePayload, Nil) {
  let decoder = {
    use role <- decode.field("role", project_role_codec.project_role_decoder())
    decode.success(RolePayload(role: role))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}
