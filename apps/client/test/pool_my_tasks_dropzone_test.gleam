import gleam/int
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/card
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/pool/my_tasks_dropzone
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn my_tasks_dropzone_renders_drag_empty_state_without_root_model_test() {
  let html =
    my_tasks_dropzone.view(my_tasks_dropzone.Config(
      locale: locale.En,
      drag_armed: True,
      drag_over: False,
      claimed_tasks: [],
      task_row_config: row_config(),
    ))
    |> element.to_document_string

  assert_contains(html, "My tasks")
  assert_contains(html, "pool-my-tasks-dropzone drag-active")
  assert_contains(html, "Claim: My tasks")
  assert_contains(html, "No tasks in My Tasks yet")
}

pub fn my_tasks_dropzone_renders_claimed_tasks_without_root_model_test() {
  let html =
    my_tasks_dropzone.view(my_tasks_dropzone.Config(
      locale: locale.En,
      drag_armed: True,
      drag_over: True,
      claimed_tasks: [claimed_task()],
      task_row_config: row_config(),
    ))
    |> element.to_document_string

  assert_contains(html, "pool-my-tasks-dropzone drop-over")
  assert_contains(html, "Prepare release")
  assert_contains(html, "Release card")
  assert_contains(html, "Start")
  assert_not_contains(html, "No tasks in My Tasks yet")
}

fn row_config() -> my_bar_view.TaskRowConfig(String) {
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
    on_complete: fn(task_id, version) {
      "complete:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_task_open: fn(task_id) { "open:" <> int.to_string(task_id) },
  )
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_status.Taken,
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
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: Some(9),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}
