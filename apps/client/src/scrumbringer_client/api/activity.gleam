//// Activity feed API functions.

import domain/activity/activity_codec
import domain/activity/entity.{type ActivityEvent}
import domain/api_error.{type ApiResult}
import gleam/dynamic/decode
import gleam/int
import gleam/option
import lustre/effect.{type Effect}
import scrumbringer_client/api/core

pub fn list_task_activity(
  task_id: Int,
  to_msg: fn(ApiResult(List(ActivityEvent))) -> msg,
) -> Effect(msg) {
  list_activity(
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/activity",
    to_msg,
  )
}

pub fn list_card_activity(
  card_id: Int,
  to_msg: fn(ApiResult(List(ActivityEvent))) -> msg,
) -> Effect(msg) {
  list_activity(
    "/api/v1/cards/" <> int.to_string(card_id) <> "/activity",
    to_msg,
  )
}

fn list_activity(
  url: String,
  to_msg: fn(ApiResult(List(ActivityEvent))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "activity",
      decode.list(activity_codec.activity_decoder()),
      decode.success,
    )

  core.request(core.Get, url, option.None, decoder, to_msg)
}
