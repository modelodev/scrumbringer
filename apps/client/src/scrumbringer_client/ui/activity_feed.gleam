//// Compact activity feed for Card Show and Task Show.

import domain/activity/entity.{type ActivityEvent}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, li, span, text, ul}

pub type Config {
  Config(
    events: Remote(List(ActivityEvent)),
    loading_label: String,
    empty_label: String,
    error_label: String,
  )
}

pub fn view(config: Config) -> Element(msg) {
  case config.events {
    NotAsked | Loading ->
      detail_empty("activity-feed-loading", config.loading_label)
    Failed(_) -> detail_empty("activity-feed-error", config.error_label)
    Loaded([]) -> detail_empty("activity-feed-empty", config.empty_label)
    Loaded(events) -> activity_list(events)
  }
}

fn activity_list(events: List(ActivityEvent)) -> Element(msg) {
  ul([attribute.class("activity-feed")], list.map(events, activity_item))
}

fn activity_item(event: ActivityEvent) -> Element(msg) {
  li([attribute.class("activity-feed-item")], [
    span([attribute.class("activity-feed-dot")], []),
    div([attribute.class("activity-feed-copy")], [
      div([attribute.class("activity-feed-main")], [
        span([attribute.class("activity-feed-actor")], [text(event.actor_label)]),
        span([attribute.class("activity-feed-summary")], [text(event.summary)]),
      ]),
      span([attribute.class("activity-feed-time")], [text(event.created_at)]),
    ]),
  ])
}

fn detail_empty(class: String, label: String) -> Element(msg) {
  div([attribute.class("detail-empty " <> class)], [text(label)])
}
