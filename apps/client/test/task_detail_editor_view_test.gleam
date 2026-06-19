import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskType, TaskTypeInline}
import scrumbringer_client/features/tasks/detail_editor
import scrumbringer_client/i18n/locale

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
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
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

fn config(current_user_id) -> detail_editor.Config(String) {
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
    task_types: Loaded([
      TaskType(
        id: 1,
        name: "Bug",
        icon: "bug-ant",
        capability_id: None,
        tasks_count: 0,
      ),
    ]),
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

pub fn detail_editor_renders_config_data_without_root_model_test() {
  let html =
    detail_editor.view_readonly_fields(config(Some(7)), claimed_task())
    |> element.to_document_string

  assert_contains(html, "Details")
  assert_contains(html, "Edit task")
  assert_contains(html, "Review release checklist.")
}

pub fn detail_editor_hides_edit_for_other_claimed_task_test() {
  let html =
    detail_editor.view_readonly_fields(config(Some(8)), claimed_task())
    |> element.to_document_string

  assert_not_contains(html, "Edit task")
  assert_contains(html, "claim the task to keep editing")
}

pub fn detail_editor_hides_edit_for_completed_task_test() {
  let completed_state = task_state.Done("2026-06-14T12:00:00Z")
  let task =
    Task(
      ..claimed_task(),
      state: completed_state,
      status: task_state.to_status(completed_state),
      work_state: task_state.to_work_state(completed_state),
    )
  let html =
    detail_editor.view_readonly_fields(config(Some(7)), task)
    |> element.to_document_string

  assert_not_contains(html, "Edit task")
  assert_contains(html, "Done tasks are read-only")
  assert_not_contains(html, "claim the task to keep editing")
}

pub fn detail_editor_marks_current_type_option_selected_test() {
  let task_type =
    TaskType(
      id: 1,
      name: "Bug",
      icon: "bug-ant",
      capability_id: None,
      tasks_count: 0,
    )
  let html =
    detail_editor.view_form(
      detail_editor.Config(
        ..config(Some(7)),
        editing: True,
        task_types: Loaded([task_type]),
      ),
      claimed_task(),
    )
    |> element.to_document_string

  assert_contains(html, "value=\"1\"")
  assert_contains(html, "selected")
}

pub fn detail_editor_renders_segmented_priority_test() {
  let html =
    detail_editor.view_form(
      detail_editor.Config(..config(Some(7)), editing: True),
      claimed_task(),
    )
    |> element.to_document_string

  assert_contains(html, "task-priority-segmented")
  assert_contains(html, "P1")
  assert_contains(html, "P5")
  assert_contains(html, "aria-pressed=\"true\"")
}
