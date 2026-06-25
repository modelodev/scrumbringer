import gleam/int
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/card
import domain/metrics.{MyMetrics, WindowDays}
import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_state.Taken,
    )

  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: None,
    priority: 2,
    state: state,
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: Some(9),
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

fn claimed_task_with_card() -> Task {
  Task(
    ..claimed_task(),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
  )
}

fn config() -> my_bar_view.TaskRowConfig(String) {
  my_bar_view.TaskRowConfig(
    locale: locale.En,
    theme: theme.Default,
    user_id: 7,
    active_task_id: None,
    disable_actions: False,
    task_card_info: fn(_task) { #(Some("Release card"), Some(card.Blue)) },
    on_claim: fn(task_id, version) {
      "claim:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_start: fn(task_id) { "start:" <> int.to_string(task_id) },
    on_pause: "pause",
    on_release: fn(task_id, version) {
      "release:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_close: fn(task_id, version) {
      "close:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_task_open: fn(task_id) { "open:" <> int.to_string(task_id) },
  )
}

fn bar_config(tasks: List(Task)) -> my_bar_view.Config(String) {
  my_bar_view.Config(
    locale: locale.En,
    has_active_projects: True,
    member_tasks: remote.Loaded(tasks),
    member_metrics: remote.Loaded(MyMetrics(
      window_days: WindowDays(14),
      claimed_count: 5,
      released_count: 2,
      closed_count: 3,
    )),
    task_row_config: config(),
    on_create_task_in_card: fn(card_id) {
      "create-in-card:" <> int.to_string(card_id)
    },
  )
}

pub fn member_bar_task_row_renders_from_config_test() {
  let html =
    my_bar_view.view_member_bar_task_row(config(), claimed_task())
    |> element.to_document_string

  assert_contains(html, "Prepare release")
  assert_contains(html, "Release card")
  assert_contains(html, "P2")
  assert_contains(html, "Bug")
  assert_contains(html, "Start")
  assert_contains(html, "Release")
  assert_contains(html, "Close task")
}

pub fn my_bar_section_renders_from_config_test() {
  let html =
    my_bar_view.view_bar(bar_config([claimed_task_with_card()]))
    |> element.to_document_string

  assert_contains(html, "My Metrics")
  assert_contains(html, "Window: 14 days")
  assert_contains(html, "Claimed")
  assert_contains(html, "Released")
  assert_contains(html, "Closed")
  assert_contains(html, "Release card")
  assert_contains(html, "Prepare release")
  assert_contains(html, "Add task to Release card")
  assert_contains(html, "my-bar-add-task")
  assert_contains(html, "btn-entity-action")
  assert_not_contains(html, "class=\"btn-icon btn-sm my-bar-add-task\"")
}
