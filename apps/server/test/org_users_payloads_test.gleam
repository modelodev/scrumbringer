import gleam/dynamic/decode
import gleam/json

import domain/org_role
import domain/project_role
import scrumbringer_server/http/org_users/payloads

pub fn decode_org_role_payload_test() {
  let assert Ok(dynamic) =
    json.parse("{\"org_role\":\"admin\"}", decode.dynamic)

  let assert Ok(payloads.OrgRolePayload(org_role: org_role.Admin)) =
    payloads.decode_org_role(dynamic)
}

pub fn decode_org_role_payload_rejects_missing_role_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_org_role(dynamic)
}

pub fn decode_org_role_payload_rejects_invalid_role_test() {
  let assert Ok(dynamic) =
    json.parse("{\"org_role\":\"manager\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_org_role(dynamic)
}

pub fn decode_user_project_payload_test() {
  let assert Ok(dynamic) =
    json.parse("{\"project_id\":7,\"role\":\"manager\"}", decode.dynamic)

  let assert Ok(payloads.UserProjectPayload(
    project_id: 7,
    role: project_role.Manager,
  )) = payloads.decode_user_project(dynamic)
}

pub fn decode_user_project_payload_defaults_role_test() {
  let assert Ok(dynamic) = json.parse("{\"project_id\":7}", decode.dynamic)

  let assert Ok(payloads.UserProjectPayload(
    project_id: 7,
    role: project_role.Member,
  )) = payloads.decode_user_project(dynamic)
}

pub fn decode_user_project_payload_rejects_missing_project_id_test() {
  let assert Ok(dynamic) = json.parse("{\"role\":\"member\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_user_project(dynamic)
}

pub fn decode_user_project_payload_rejects_invalid_role_test() {
  let assert Ok(dynamic) =
    json.parse("{\"project_id\":7,\"role\":\"admin\"}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_user_project(dynamic)
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
