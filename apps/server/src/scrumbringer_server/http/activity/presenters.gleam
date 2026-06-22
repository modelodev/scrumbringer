//// HTTP presenters for activity feeds.

import domain/activity/activity_codec
import domain/activity/entity.{type ActivityEvent}
import gleam/json

pub fn activity_response(events: List(ActivityEvent)) -> json.Json {
  json.object([
    #("activity", json.array(events, of: activity_codec.to_json)),
  ])
}
