//// Compact activity feed for Card Show and Task Show.

import domain/activity/entity.{type ActivityEvent}
import domain/activity/id as activity_id
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, li, span, text}
import lustre/element/keyed
import lustre/event
import scrumbringer_client/utils/format_date

type ActivityGroup {
  ActivityGroup(date: String, events: List(ActivityEvent))
}

pub type LoadMore(msg) {
  LoadMore(label: String, in_flight: Bool, on_click: msg)
}

pub type Config(msg) {
  Config(
    events: Remote(List(ActivityEvent)),
    loading_label: String,
    empty_label: String,
    error_label: String,
    load_more: Option(LoadMore(msg)),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.events {
    NotAsked | Loading ->
      detail_empty("activity-feed-loading", config.loading_label)
    Failed(_) -> detail_empty("activity-feed-error", config.error_label)
    Loaded([]) -> detail_empty("activity-feed-empty", config.empty_label)
    Loaded(events) -> activity_list(events, config)
  }
}

fn activity_list(
  events: List(ActivityEvent),
  config: Config(msg),
) -> Element(msg) {
  div([attribute.class("activity-feed-shell")], [
    keyed.element(
      "div",
      [attribute.class("activity-feed")],
      events
        |> activity_groups
        |> list.map(fn(group) { #(group.date, activity_group(group)) }),
    ),
    load_more(config.load_more),
  ])
}

fn activity_group(group: ActivityGroup) -> Element(msg) {
  div([attribute.class("activity-feed-group")], [
    div([attribute.class("activity-feed-date")], [text(group.date)]),
    keyed.element(
      "ul",
      [attribute.class("activity-feed-items")],
      group.events
        |> list.map(fn(event) { #(event_key(event), activity_item(event)) }),
    ),
  ])
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

fn activity_groups(events: List(ActivityEvent)) -> List(ActivityGroup) {
  events
  |> list.fold([], fn(groups, event) { upsert_activity_group(groups, event) })
  |> list.reverse
  |> list.map(fn(group) {
    ActivityGroup(..group, events: list.reverse(group.events))
  })
}

fn upsert_activity_group(
  groups: List(ActivityGroup),
  event: ActivityEvent,
) -> List(ActivityGroup) {
  case groups {
    [] -> [new_activity_group(event)]
    [group, ..rest] -> {
      case group.date == activity_date(event) {
        True -> [
          ActivityGroup(..group, events: [event, ..group.events]),
          ..rest
        ]
        False -> [group, ..upsert_activity_group(rest, event)]
      }
    }
  }
}

fn new_activity_group(event: ActivityEvent) -> ActivityGroup {
  ActivityGroup(date: activity_date(event), events: [event])
}

fn activity_date(event: ActivityEvent) -> String {
  format_date.date_only(event.created_at)
}

fn event_key(event: ActivityEvent) -> String {
  event.id
  |> activity_id.to_int
  |> int.to_string
}

fn load_more(config: Option(LoadMore(msg))) -> Element(msg) {
  case config {
    None -> element.none()
    Some(LoadMore(label: label, in_flight: in_flight, on_click: on_click)) ->
      button(
        [
          attribute.class("activity-feed-more"),
          attribute.type_("button"),
          attribute.disabled(in_flight),
          event.on_click(on_click),
        ],
        [text(label)],
      )
  }
}

fn detail_empty(class: String, label: String) -> Element(msg) {
  div([attribute.class("detail-empty " <> class)], [text(label)])
}
