import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element

import domain/remote.{NotAsked}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_detail_details
import scrumbringer_client/features/tasks/detail_editor
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn task_detail_details_renders_loaded_task_without_root_model_test() {
  let html =
    task_detail_details.view(config(Some(claimed_task()), Some(7)))
    |> element.to_document_string

  assert_contains(html, "Details")
  assert_contains(html, "Edit task")
  assert_contains(html, "Release card")
  assert_contains(html, "Review release checklist.")
}

pub fn task_detail_details_renders_loading_state_test() {
  let html =
    task_detail_details.view(config(None, None))
    |> element.to_document_string

  assert_contains(html, "Loading")
  assert_contains(html, "task-details-section")
  assert_not_contains(html, "Edit task")
}

fn config(
  task: Option(Task),
  current_user_id: Option(Int),
) -> task_detail_details.Config(String) {
  task_detail_details.Config(
    locale: locale.En,
    task: task,
    dependencies: NotAsked,
    parent_card_title: Some("Release card"),
    editor: editor_config(current_user_id),
  )
}

fn editor_config(current_user_id: Option(Int)) -> detail_editor.Config(String) {
  detail_editor.Config(
    locale: locale.En,
    current_user_id: current_user_id,
    editing: False,
    edit_title: "Prepare release",
    edit_description: "Review release checklist.",
    edit_priority: "2",
    edit_type_id: "1",
    edit_card_id: "",
    edit_error: None,
    edit_in_flight: False,
    task_types: NotAsked,
    cards: [],
    on_edit_started: "edit-started",
    on_edit_cancelled: "edit-cancelled",
    on_title_changed: fn(value) { "title:" <> value },
    on_description_changed: fn(value) { "description:" <> value },
    on_priority_changed: fn(value) { "priority:" <> value },
    on_type_id_changed: fn(value) { "type:" <> value },
    on_card_id_changed: fn(value) { "card:" <> value },
    on_submitted: "submitted",
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
    description: Some("Review release checklist."),
    priority: 2,
    state: state,
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}
