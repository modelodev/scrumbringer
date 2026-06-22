//// HTTP presenters for activity feeds.

import domain/activity/activity_codec
import domain/activity/entity.{type ActivityEvent}
import gleam/json

pub fn activity_response(
  events: List(ActivityEvent),
  limit: Int,
  offset: Int,
  total: Int,
) -> json.Json {
  json.object([
    #("activity", json.array(events, of: activity_codec.to_json)),
    #("pagination", pagination_json(limit, offset, total)),
  ])
}

fn pagination_json(limit: Int, offset: Int, total: Int) -> json.Json {
  json.object([
    #("limit", json.int(limit)),
    #("offset", json.int(offset)),
    #("total", json.int(total)),
  ])
}
