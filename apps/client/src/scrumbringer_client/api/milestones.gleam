//// Milestones API functions for Scrumbringer client.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}

import domain/milestone.{type Milestone, type MilestoneProgress}
import domain/milestone/codec as milestone_codec

pub fn list_milestones(
  project_id: Int,
  to_msg: fn(ApiResult(List(MilestoneProgress))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "milestones",
      decode.list(milestone_codec.milestone_progress_decoder()),
      decode.success,
    )

  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/milestones",
    option.None,
    decoder,
    to_msg,
  )
}

pub fn activate_milestone(
  milestone_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request(
    "POST",
    "/api/v1/milestones/" <> int.to_string(milestone_id) <> "/activate",
    option.Some(json.object([])),
    decode.success(Nil),
    to_msg,
  )
}

pub fn update_milestone(
  milestone_id: Int,
  name: String,
  description: String,
  to_msg: fn(ApiResult(Milestone)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
    ])

  core.request(
    "PATCH",
    "/api/v1/milestones/" <> int.to_string(milestone_id),
    option.Some(body),
    decode.field(
      "milestone",
      milestone_codec.milestone_decoder(),
      decode.success,
    ),
    to_msg,
  )
}

pub fn delete_milestone(
  milestone_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/milestones/" <> int.to_string(milestone_id),
    option.None,
    to_msg,
  )
}
