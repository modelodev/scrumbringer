//// JSON payload decoders for project endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

import domain/project.{type ProjectDepthName, ProjectDepthName}
import domain/project_role.{type ProjectRole}
import domain/project_role/project_role_codec

pub type ProjectCreatePayload {
  ProjectCreatePayload(
    name: String,
    healthy_pool_limit: Int,
    card_depth_names: List(ProjectDepthName),
  )
}

pub type ProjectUpdatePayload {
  ProjectUpdatePayload(
    name: String,
    healthy_pool_limit: Int,
    card_depth_names: List(ProjectDepthName),
  )
}

pub type DepthReductionPreviewPayload {
  DepthReductionPreviewPayload(new_max_depth: Int)
}

pub type MemberPayload {
  MemberPayload(user_id: Int, role: ProjectRole)
}

pub type RolePayload {
  RolePayload(role: ProjectRole)
}

pub fn decode_project_create(data: Dynamic) -> Result(ProjectCreatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use healthy_pool_limit <- decode.field("healthy_pool_limit", decode.int)
    use card_depth_names <- decode.field(
      "card_depth_names",
      decode.list(project_depth_name_decoder()),
    )
    decode.success(ProjectCreatePayload(
      name: name,
      healthy_pool_limit: healthy_pool_limit,
      card_depth_names: card_depth_names,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_project_update(data: Dynamic) -> Result(ProjectUpdatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use healthy_pool_limit <- decode.field("healthy_pool_limit", decode.int)
    use card_depth_names <- decode.field(
      "card_depth_names",
      decode.list(project_depth_name_decoder()),
    )
    decode.success(ProjectUpdatePayload(
      name: name,
      healthy_pool_limit: healthy_pool_limit,
      card_depth_names: card_depth_names,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_depth_reduction_preview(
  data: Dynamic,
) -> Result(DepthReductionPreviewPayload, Nil) {
  let decoder = {
    use new_max_depth <- decode.field("new_max_depth", decode.int)
    decode.success(DepthReductionPreviewPayload(new_max_depth: new_max_depth))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
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
