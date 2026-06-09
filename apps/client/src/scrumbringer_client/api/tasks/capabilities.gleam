//// User capabilities API functions.
////
//// ## Mission
////
//// Provides API operations for member capability management within a project.
////
//// ## Responsibilities
////
//// - Get member's capability IDs for a project
//// - Update member's capability IDs for a project
////
//// ## Relations
////
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import scrumbringer_client/api/core

// =============================================================================
// Member Capability API Functions (Project-Scoped)
// =============================================================================

/// Get member's capability IDs for a project.
pub fn get_member_capability_ids(
  project_id: Int,
  user_id: Int,
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  core.request(
    core.Get,
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id)
      <> "/capabilities",
    option.None,
    decoder,
    to_msg,
  )
}

/// Update member's capability IDs for a project.
pub fn put_member_capability_ids(
  project_id: Int,
  user_id: Int,
  ids: List(Int),
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let body = json.object([#("capability_ids", json.array(ids, of: json.int))])
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  core.request(
    core.Put,
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id)
      <> "/capabilities",
    option.Some(body),
    decoder,
    to_msg,
  )
}
