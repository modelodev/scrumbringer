import gleam/dynamic/decode
import gleam/json

import domain/project/project_codec
import domain/project_role

pub fn default_card_depth_names_include_three_operational_levels_test() {
  let assert [first, second, third] = project_codec.default_card_depth_names()

  let assert 1 = first.depth
  let assert "Initiatives" = first.plural_name
  let assert 2 = second.depth
  let assert "Features" = second.plural_name
  let assert 3 = third.depth
  let assert "Task groups" = third.plural_name
}

pub fn project_decoder_uses_three_depth_fallback_levels_test() {
  let payload =
    json.object([
      #("id", json.int(7)),
      #("name", json.string("Core")),
      #("my_role", json.string(project_role.to_string(project_role.Manager))),
      #("created_at", json.string("2026-06-20T08:00:00Z")),
      #("members_count", json.int(1)),
    ])
    |> json.to_string

  let assert Ok(dynamic) = json.parse(payload, decode.dynamic)
  let assert Ok(project) = decode.run(dynamic, project_codec.project_decoder())
  let assert [_, _, third] = project.card_depth_names
  let assert 3 = third.depth
  let assert "Task group" = third.singular_name
  let assert "Task groups" = third.plural_name
}
