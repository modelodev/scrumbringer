import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/activity/entity.{type ActivityEvent, ActivityEvent}
import domain/activity/id as activity_id
import domain/activity/kind
import domain/activity/subject.{ActivityTask}
import domain/project/id as project_id
import domain/remote.{Loaded}
import domain/task/id as task_id
import domain/user/id as user_id
import scrumbringer_client/ui/activity_feed

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn count_occurrences(haystack: String, needle: String) -> Int {
  case needle == "" {
    True -> 0
    False -> list.length(string.split(haystack, needle)) - 1
  }
}

pub fn activity_feed_renders_empty_state_test() {
  let html =
    activity_feed.view(activity_feed.Config(
      events: Loaded([]),
      loading_label: "Loading activity...",
      empty_label: "No activity yet.",
      error_label: "Could not load activity.",
      load_more: None,
    ))
    |> element.to_document_string

  assert_contains(html, "No activity yet.")
  assert_not_contains(html, "activity-feed-item")
}

pub fn activity_feed_renders_event_actor_summary_and_time_test() {
  let html =
    activity_feed.view(activity_feed.Config(
      events: Loaded([sample_event()]),
      loading_label: "Loading activity...",
      empty_label: "No activity yet.",
      error_label: "Could not load activity.",
      load_more: None,
    ))
    |> element.to_document_string

  assert_contains(html, "activity-feed-item")
  assert_contains(html, "admin@example.com")
  assert_contains(html, "Task claimed")
  assert_contains(html, "2026-06-22T10:30:00Z")
}

pub fn activity_feed_groups_loaded_events_by_date_test() {
  let html =
    activity_feed.view(activity_feed.Config(
      events: Loaded([
        sample_event_at(1, "Task claimed", "2026-06-22T10:30:00Z"),
        sample_event_at(2, "Task started", "2026-06-22T11:45:00Z"),
        sample_event_at(3, "Task released", "2026-06-21T16:00:00Z"),
      ]),
      loading_label: "Loading activity...",
      empty_label: "No activity yet.",
      error_label: "Could not load activity.",
      load_more: None,
    ))
    |> element.to_document_string

  assert_contains(html, "activity-feed-group")
  assert_contains(html, "activity-feed-date")
  assert_contains(html, "2026-06-22")
  assert_contains(html, "2026-06-21")
  assert_contains(html, "Task claimed")
  assert_contains(html, "Task started")
  assert_contains(html, "Task released")
  let assert 2 = count_occurrences(html, "activity-feed-date")
}

pub fn activity_feed_renders_load_more_control_when_available_test() {
  let html =
    activity_feed.view(activity_feed.Config(
      events: Loaded([sample_event()]),
      loading_label: "Loading activity...",
      empty_label: "No activity yet.",
      error_label: "Could not load activity.",
      load_more: Some(activity_feed.LoadMore(
        label: "Ver mas",
        in_flight: False,
        on_click: Nil,
      )),
    ))
    |> element.to_document_string

  assert_contains(html, "activity-feed-more")
  assert_contains(html, "Ver mas")
  assert_not_contains(html, "disabled")
}

fn sample_event() -> ActivityEvent {
  sample_event_at(1, "Task claimed", "2026-06-22T10:30:00Z")
}

fn sample_event_at(
  id: Int,
  summary: String,
  created_at: String,
) -> ActivityEvent {
  ActivityEvent(
    id: activity_id.new(id),
    project_id: project_id.new(1),
    subject: ActivityTask(task_id.new(42)),
    kind: kind.TaskClaimed,
    actor_user_id: user_id.new(7),
    actor_label: "admin@example.com",
    summary: summary,
    related_subject: option.None,
    created_at: created_at,
  )
}
