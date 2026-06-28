import gleam/option.{None, Some}
import support/render_assertions

import domain/activity/entity.{type ActivityEvent, ActivityEvent}
import domain/activity/id as activity_id
import domain/activity/kind
import domain/activity/subject.{ActivityTask}
import domain/project/id as project_id
import domain/remote.{Loaded}
import domain/task/id as task_id
import domain/user/id as user_id
import scrumbringer_client/ui/activity_feed

pub fn activity_feed_renders_empty_state_test() {
  let html =
    activity_feed.view(activity_feed.Config(
      events: Loaded([]),
      loading_label: "Loading activity...",
      empty_label: "No activity yet.",
      error_label: "Could not load activity.",
      load_more: None,
    ))
    |> render_assertions.html

  render_assertions.contains(html, "No activity yet.")
  render_assertions.not_contains(html, "activity-feed-item")
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
    |> render_assertions.html

  render_assertions.contains(html, "activity-feed-item")
  render_assertions.contains(html, "admin@example.com")
  render_assertions.contains(html, "Task claimed")
  render_assertions.contains(html, "2026-06-22T10:30:00Z")
  render_assertions.contains(html, "activity-feed-copy")
  render_assertions.contains(html, "activity-feed-main")
  render_assertions.contains(html, "activity-feed-time")
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
    |> render_assertions.html

  render_assertions.contains(html, "activity-feed-group")
  render_assertions.contains(html, "activity-feed-date")
  render_assertions.contains(html, "2026-06-22")
  render_assertions.contains(html, "2026-06-21")
  render_assertions.contains(html, "Task claimed")
  render_assertions.contains(html, "Task started")
  render_assertions.contains(html, "Task released")
  render_assertions.occurs(html, "activity-feed-date", 2)
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
    |> render_assertions.html

  render_assertions.contains(html, "activity-feed-more")
  render_assertions.contains(html, "Ver mas")
  render_assertions.not_contains(html, "disabled")
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
