import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element

import domain/remote.{NotAsked}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_show_details
import scrumbringer_client/features/tasks/show_editor
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/pinned_context

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn task_show_details_renders_loaded_task_without_root_model_test() {
  let html =
    task_show_details.view(config(Some(claimed_task()), Some(7)))
    |> element.to_document_string

  assert_contains(html, "Details")
  assert_contains(html, "Edit task")
  assert_contains(html, "Release card")
  assert_not_contains(html, "Open card")
  assert_not_contains(html, "View in Plan")
  assert_contains(html, "Review release checklist.")
}

pub fn task_show_details_renders_loading_state_test() {
  let html =
    task_show_details.view(config(None, None))
    |> element.to_document_string

  assert_contains(html, "Loading")
  assert_contains(html, "task-details-section")
  assert_not_contains(html, "Edit task")
}

pub fn task_show_details_renders_pinned_context_test() {
  let html =
    task_show_details.view(
      config_with_pins(Some(claimed_task()), Some(7), [
        pinned_note(1, "Spec"),
        pinned_note(2, "Decision"),
        pinned_note(3, "PR"),
        pinned_note(4, "Extra"),
      ]),
    )
    |> element.to_document_string

  assert_contains(html, "Pinned context")
  assert_contains(html, "Spec")
  assert_contains(html, "Decision")
  assert_contains(html, "PR")
  assert_not_contains(html, "Extra")
  assert_contains(html, "+1 in notes")
}

fn config_with_pins(
  task: Option(Task),
  current_user_id: Option(Int),
  pinned_notes: List(pinned_context.PinnedNote),
) -> task_show_details.Config(String) {
  task_show_details.Config(
    locale: locale.En,
    task: task,
    dependencies: NotAsked,
    parent_card_title: Some("Release card"),
    pinned_notes: pinned_notes,
    on_open_notes: "notes",
    editor: editor_config(current_user_id),
  )
}

fn config(
  task: Option(Task),
  current_user_id: Option(Int),
) -> task_show_details.Config(String) {
  config_with_pins(task, current_user_id, [])
}

fn pinned_note(id: Int, content: String) -> pinned_context.PinnedNote {
  pinned_context.PinnedNote(id: id, content: content, url: None)
}

fn editor_config(current_user_id: Option(Int)) -> show_editor.Config(String) {
  show_editor.Config(
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
    automation_origin: None,
  )
}
