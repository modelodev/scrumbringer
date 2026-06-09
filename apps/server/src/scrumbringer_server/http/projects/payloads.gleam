//// JSON payload decoders for project endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

import domain/project_role.{type ProjectRole}
import domain/project_role/codec as project_role_codec

pub type ProjectNamePayload {
  ProjectNamePayload(name: String)
}

pub type MemberPayload {
  MemberPayload(user_id: Int, role: ProjectRole)
}

pub type RolePayload {
  RolePayload(role: ProjectRole)
}

pub fn decode_project_name(data: Dynamic) -> Result(ProjectNamePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(ProjectNamePayload(name: name))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_member(data: Dynamic) -> Result(MemberPayload, Nil) {
  let decoder = {
    use user_id <- decode.field("user_id", decode.int)
    use role <- decode.field("role", project_role_codec.project_role_decoder())
    decode.success(MemberPayload(user_id: user_id, role: role))
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
