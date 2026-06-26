//// Project member capability API.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import scrumbringer_client/api/core

pub type MemberCapabilities {
  MemberCapabilities(user_id: Int, capability_ids: List(Int))
}

pub fn get_member_capabilities(
  project_id: Int,
  user_id: Int,
  to_msg: fn(ApiResult(MemberCapabilities)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    endpoint(project_id, user_id),
    option.None,
    decoder(user_id),
    to_msg,
  )
}

pub fn set_member_capabilities(
  project_id: Int,
  user_id: Int,
  capability_ids: List(Int),
  to_msg: fn(ApiResult(MemberCapabilities)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("capability_ids", json.array(capability_ids, of: json.int)),
    ])

  core.request(
    core.Put,
    endpoint(project_id, user_id),
    option.Some(body),
    decoder(user_id),
    to_msg,
  )
}

pub fn get_member_capability_ids(
  project_id: Int,
  user_id: Int,
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  get_member_capabilities(project_id, user_id, fn(result) {
    to_msg(ids_result(result))
  })
}

pub fn put_member_capability_ids(
  project_id: Int,
  user_id: Int,
  ids: List(Int),
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  set_member_capabilities(project_id, user_id, ids, fn(result) {
    to_msg(ids_result(result))
  })
}

fn endpoint(project_id: Int, user_id: Int) -> String {
  "/api/v1/projects/"
  <> int.to_string(project_id)
  <> "/members/"
  <> int.to_string(user_id)
  <> "/capabilities"
}

fn decoder(user_id: Int) {
  use ids <- decode.field("capability_ids", decode.list(decode.int))
  decode.success(MemberCapabilities(user_id: user_id, capability_ids: ids))
}

fn ids_result(result: ApiResult(MemberCapabilities)) -> ApiResult(List(Int)) {
  case result {
    Ok(MemberCapabilities(capability_ids: ids, ..)) -> Ok(ids)
    Error(err) -> Error(err)
  }
}
