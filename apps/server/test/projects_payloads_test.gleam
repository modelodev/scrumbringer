import gleam/dynamic/decode
import gleam/json

import domain/project as domain_project
import domain/project_role
import scrumbringer_server/http/projects/payloads

pub fn decode_project_create_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"name\":\"Alpha\",\"healthy_pool_limit\":12,\"card_depth_names\":[{\"depth\":1,\"singular_name\":\"Card\",\"plural_name\":\"Cards\"}]}",
      decode.dynamic,
    )

  let assert Ok(payloads.ProjectCreatePayload(
    name: "Alpha",
    healthy_pool_limit: 12,
    card_depth_names: depth_names,
  )) = payloads.decode_project_create(dynamic)
  let assert [
    domain_project.ProjectDepthName(
      depth: 1,
      singular_name: "Card",
      plural_name: "Cards",
    ),
  ] = depth_names
}

pub fn decode_project_create_payload_rejects_missing_settings_test() {
  let assert Ok(dynamic) = json.parse("{\"name\":\"Alpha\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_project_create(dynamic)
}

pub fn decode_project_create_payload_rejects_missing_name_test() {
  let assert Ok(dynamic) = json.parse("{\"title\":\"Alpha\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_project_create(dynamic)
}

pub fn decode_member_payload_test() {
  let assert Ok(dynamic) =
    json.parse("{\"user_id\":12,\"role\":\"manager\"}", decode.dynamic)

  let assert Ok(payloads.MemberPayload(user_id: 12, role: project_role.Manager)) =
    payloads.decode_member(dynamic)
}

pub fn decode_member_payload_rejects_wrong_user_id_type_test() {
  let assert Ok(dynamic) =
    json.parse("{\"user_id\":\"12\",\"role\":\"manager\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_member(dynamic)
}

pub fn decode_member_payload_rejects_invalid_role_test() {
  let assert Ok(dynamic) =
    json.parse("{\"user_id\":12,\"role\":\"admin\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_member(dynamic)
}

pub fn decode_role_payload_test() {
  let assert Ok(dynamic) = json.parse("{\"role\":\"member\"}", decode.dynamic)

  let assert Ok(payloads.RolePayload(role: project_role.Member)) =
    payloads.decode_role(dynamic)
}

pub fn decode_role_payload_rejects_missing_role_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_role(dynamic)
}

pub fn decode_role_payload_rejects_invalid_role_test() {
  let assert Ok(dynamic) = json.parse("{\"role\":\"admin\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_role(dynamic)
}
