import gleam/int
import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/card
import domain/task.{type Task, Task}
import domain/task/state as task_state
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/pool/my_tasks_dropzone
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

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

  render_assertions.contains(html, "My tasks")
  render_assertions.contains(html, "pool-my-tasks-dropzone drag-active")
  render_assertions.contains(html, "Claim: My tasks")
  render_assertions.contains(html, "No tasks in My Tasks yet")
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

  render_assertions.contains(html, "pool-my-tasks-dropzone drop-over")
  render_assertions.contains(html, "Prepare release")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "Start")
  render_assertions.not_contains(html, "No tasks in My Tasks yet")
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
    on_close: fn(task_id, version) {
      "close:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_task_open: fn(task_id) { "open:" <> int.to_string(task_id) },
  )
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_state.Taken,
    )

  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    description: None,
    priority: 2,
    state: state,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
    card_id: Some(9),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
  )
}
