import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/remote.{Loaded}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskType}
import scrumbringer_client/features/tasks/show_editor
import scrumbringer_client/i18n/locale

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_state.Taken,
    )

  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    description: Some("Review release checklist."),
    priority: 2,
    state: state,
  )
}

fn config(current_user_id) -> show_editor.Config(String) {
  show_editor.Config(
    locale: locale.En,
    current_user_id: current_user_id,
    editing: False,
    edit_title: "Prepare release",
    edit_description: "Review release checklist.",
    edit_priority: "2",
    edit_type_id: "1",
    edit_card_id: "",
    edit_card_query: "",
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
    depth_names: [],
    on_edit_started: "edit-started",
    on_edit_cancelled: "edit-cancelled",
    on_title_changed: fn(value) { "title:" <> value },
    on_description_changed: fn(value) { "description:" <> value },
    on_priority_changed: fn(value) { "priority:" <> value },
    on_type_id_changed: fn(value) { "type:" <> value },
    on_card_id_changed: fn(value) { "card:" <> value },
    on_card_query_changed: fn(value) { "card-query:" <> value },
    on_submitted: "submitted",
  )
}

pub fn show_editor_renders_config_data_without_root_model_test() {
  let html =
    show_editor.view_readonly_fields(config(Some(7)), claimed_task())
    |> element.to_document_string

  render_assertions.contains(html, "Details")
  render_assertions.contains(html, "Edit task")
  render_assertions.contains(html, "Review release checklist.")
}

pub fn show_editor_hides_edit_for_other_claimed_task_test() {
  let html =
    show_editor.view_readonly_fields(config(Some(8)), claimed_task())
    |> element.to_document_string

  render_assertions.not_contains(html, "Edit task")
  render_assertions.contains(html, "claim the task to keep editing")
}

pub fn show_editor_hides_edit_for_closed_task_test() {
  let closed_state =
    task_state.Closed(task_state.ClosedByClaimant, "2026-06-14T12:00:00Z", 7)
  let task = Task(..claimed_task(), state: closed_state)
  let html =
    show_editor.view_readonly_fields(config(Some(7)), task)
    |> element.to_document_string

  render_assertions.not_contains(html, "Edit task")
  render_assertions.contains(html, "Closed tasks are read-only")
  render_assertions.not_contains(html, "claim the task to keep editing")
}

pub fn show_editor_marks_current_type_option_selected_test() {
  let task_type =
    TaskType(
      id: 1,
      name: "Bug",
      icon: "bug-ant",
      capability_id: None,
      tasks_count: 0,
    )
  let html =
    show_editor.view_form(
      show_editor.Config(
        ..config(Some(7)),
        editing: True,
        task_types: Loaded([task_type]),
      ),
      claimed_task(),
    )
    |> element.to_document_string

  render_assertions.contains(html, "value=\"1\"")
  render_assertions.contains(html, "selected")
}

pub fn show_editor_renders_segmented_priority_test() {
  let html =
    show_editor.view_form(
      show_editor.Config(..config(Some(7)), editing: True),
      claimed_task(),
    )
    |> element.to_document_string

  render_assertions.contains(html, "task-priority-segmented")
  render_assertions.contains(html, "P1")
  render_assertions.contains(html, "P5")
  render_assertions.contains(html, "aria-pressed=\"true\"")
}
