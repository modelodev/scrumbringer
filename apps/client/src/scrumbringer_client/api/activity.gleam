//// Activity feed API functions.

import domain/activity/activity_codec
import domain/activity/entity.{type ActivityEvent}
import domain/api_error.{type ApiResult}
import gleam/dynamic/decode
import gleam/int
import gleam/option
import lustre/effect.{type Effect}
import scrumbringer_client/api/core

const default_limit = 30

const first_offset = 0

pub type Pagination {
  Pagination(limit: Int, offset: Int, total: Int)
}

pub type ActivityPage {
  ActivityPage(activity: List(ActivityEvent), pagination: Pagination)
}

pub fn list_task_activity(
  task_id: Int,
  to_msg: fn(ApiResult(ActivityPage)) -> msg,
) -> Effect(msg) {
  list_task_activity_page(task_id, default_limit, first_offset, to_msg)
}

pub fn list_task_activity_page(
  task_id: Int,
  limit: Int,
  offset: Int,
  to_msg: fn(ApiResult(ActivityPage)) -> msg,
) -> Effect(msg) {
  list_activity(task_activity_url(task_id, limit, offset), to_msg)
}

pub fn list_card_activity(
  card_id: Int,
  to_msg: fn(ApiResult(ActivityPage)) -> msg,
) -> Effect(msg) {
  list_card_activity_page(card_id, default_limit, first_offset, to_msg)
}

pub fn list_card_activity_page(
  card_id: Int,
  limit: Int,
  offset: Int,
  to_msg: fn(ApiResult(ActivityPage)) -> msg,
) -> Effect(msg) {
  list_activity(card_activity_url(card_id, limit, offset), to_msg)
}

pub fn task_activity_url(task_id: Int, limit: Int, offset: Int) -> String {
  "/api/v1/tasks/"
  <> int.to_string(task_id)
  <> "/activity?limit="
  <> int.to_string(limit)
  <> "&offset="
  <> int.to_string(offset)
}

pub fn card_activity_url(card_id: Int, limit: Int, offset: Int) -> String {
  "/api/v1/cards/"
  <> int.to_string(card_id)
  <> "/activity?limit="
  <> int.to_string(limit)
  <> "&offset="
  <> int.to_string(offset)
}

fn list_activity(
  url: String,
  to_msg: fn(ApiResult(ActivityPage)) -> msg,
) -> Effect(msg) {
  core.request(core.Get, url, option.None, activity_page_decoder(), to_msg)
}

pub fn activity_page_decoder() -> decode.Decoder(ActivityPage) {
  use activity <- decode.field(
    "activity",
    decode.list(activity_codec.activity_decoder()),
  )
  use pagination <- decode.field("pagination", pagination_decoder())
  decode.success(ActivityPage(activity: activity, pagination: pagination))
}

fn pagination_decoder() -> decode.Decoder(Pagination) {
  use limit <- decode.field("limit", decode.int)
  use offset <- decode.field("offset", decode.int)
  use total <- decode.field("total", decode.int)
  decode.success(Pagination(limit: limit, offset: offset, total: total))
}
