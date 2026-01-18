//// User capabilities API functions.
////
//// ## Mission
////
//// Provides API operations for user capability management.
////
//// ## Responsibilities
////
//// - Get user's capability IDs
//// - Update user's capability IDs
////
//// ## Relations
////
//// - **../core.gleam**: Provides HTTP request infrastructure

import gleam/dynamic/decode
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import scrumbringer_client/api/core

// =============================================================================
// User Capability API Functions
// =============================================================================

/// Get current user's capability IDs.
pub fn get_me_capability_ids(
  to_msg: fn(core.ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  core.request("GET", "/api/v1/me/capabilities", option.None, decoder, to_msg)
}

/// Update current user's capability IDs.
pub fn put_me_capability_ids(
  ids: List(Int),
  to_msg: fn(core.ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let body = json.object([#("capability_ids", json.array(ids, of: json.int))])
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  core.request(
    "PUT",
    "/api/v1/me/capabilities",
    option.Some(body),
    decoder,
    to_msg,
  )
}
