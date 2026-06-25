import gleam/option.{None, Some}

import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/show_edit_form
import scrumbringer_client/features/tasks/show_state
import scrumbringer_client/ui/show_tabs

fn sample_task() -> Task {
  let state = task_state.Available
  Task(
    id: 42,
    project_id: 1,
    type_id: 7,
    task_type: TaskTypeInline(id: 7, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Review checklist."),
    priority: 4,
    state: state,
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: Some(12),
    card_id: Some(9),
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

fn submission(title: String, description: String) -> show_edit_form.Submission {
  show_edit_form.Submission(
    title: title,
    description: description,
    priority: 2,
    type_id: 1,
    card_id: None,
  )
}

pub fn show_state_open_sets_loading_show_state_test() {
  let #(pool, notes, dependencies) =
    show_state.open(
      member_pool.default_model(),
      member_notes.default_model(),
      member_dependencies.default_model(),
      42,
      Some(sample_task()),
    )

  let assert show_tabs.TaskDetailsTab = pool.member_task_show_tab
  let assert "Prepare release" = pool.member_task_show_edit_title
  let assert "Review checklist." = pool.member_task_show_edit_description
  let assert "4" = pool.member_task_show_edit_priority
  let assert "7" = pool.member_task_show_edit_type_id
  let assert "9" = pool.member_task_show_edit_card_id
  let assert Some(42) = notes.member_notes_task_id
  let assert True = notes.member_notes == remote.Loading
  let assert True = dependencies.member_dependencies == remote.Loading
}

pub fn show_state_open_uses_inline_task_type_when_type_id_is_invalid_test() {
  let task = Task(..sample_task(), type_id: 0)
  let #(pool, _, _) =
    show_state.open(
      member_pool.default_model(),
      member_notes.default_model(),
      member_dependencies.default_model(),
      42,
      Some(task),
    )

  let assert "7" = pool.member_task_show_edit_type_id
}

pub fn show_state_close_resets_show_state_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_show_tab: show_tabs.TaskActivityTab,
      member_task_show_editing: True,
      member_task_show_edit_title: "Changed",
      member_task_show_edit_description: "Changed description",
      member_task_show_edit_priority: "5",
      member_task_show_edit_type_id: "3",
      member_task_show_edit_card_id: "9",
      member_task_show_edit_in_flight: True,
      member_task_show_edit_error: Some("old"),
    )
  let notes =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes_task_id: Some(42),
      member_notes: remote.Loading,
      member_note_content: "draft",
      member_note_dialog_mode: dialog_mode.DialogCreate,
    )

  let #(next_pool, next_notes, next_dependencies) =
    show_state.close(pool, notes)

  let assert show_tabs.TaskDetailsTab = next_pool.member_task_show_tab
  let assert False = next_pool.member_task_show_editing
  let assert "" = next_pool.member_task_show_edit_title
  let assert "" = next_pool.member_task_show_edit_description
  let assert None = next_notes.member_notes_task_id
  let assert True = next_notes.member_notes == remote.NotAsked
  let assert "" = next_notes.member_note_content
  let assert dialog_mode.DialogClosed = next_notes.member_note_dialog_mode
  let assert True = next_dependencies == member_dependencies.default_model()
}

pub fn show_state_start_edit_sets_canonical_task_values_test() {
  let next =
    show_state.start_edit(
      member_pool.default_model(),
      Some(sample_task()),
      True,
    )

  let assert True = next.member_task_show_editing
  let assert "Prepare release" = next.member_task_show_edit_title
  let assert "Review checklist." = next.member_task_show_edit_description
  let assert None = next.member_task_show_edit_error
}

pub fn show_state_start_edit_ignores_disallowed_task_test() {
  let model = member_pool.default_model()
  let next = show_state.start_edit(model, Some(sample_task()), False)

  let assert True = next == model
}

pub fn show_state_edit_decisions_update_form_state_test() {
  let invalid = show_state.edit_invalid(member_pool.default_model(), "Required")
  let unchanged =
    show_state.edit_unchanged(
      member_pool.Model(..invalid, member_task_show_editing: True),
      submission("Prepare release", "Review checklist."),
    )
  let started =
    show_state.edit_started_submit(
      member_pool.default_model(),
      submission("Updated", "Updated description"),
    )

  let assert Some("Required") = invalid.member_task_show_edit_error
  let assert False = unchanged.member_task_show_editing
  let assert "Prepare release" = unchanged.member_task_show_edit_title
  let assert "2" = unchanged.member_task_show_edit_priority
  let assert "1" = unchanged.member_task_show_edit_type_id
  let assert None = unchanged.member_task_show_edit_error
  let assert True = started.member_task_show_edit_in_flight
  let assert "Updated" = started.member_task_show_edit_title
}

pub fn show_state_task_updated_replaces_task_and_stops_editing_test() {
  let original = sample_task()
  let updated =
    Task(
      ..original,
      title: "Updated title",
      description: Some("Updated description"),
      version: 4,
    )
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([original]),
      member_task_show_editing: True,
      member_task_show_edit_in_flight: True,
      member_task_show_edit_error: Some("old"),
    )

  let next = show_state.task_updated(model, updated)

  let assert True = next.member_tasks == remote.Loaded([updated])
  let assert False = next.member_task_show_editing
  let assert "Updated title" = next.member_task_show_edit_title
  let assert "Updated description" = next.member_task_show_edit_description
  let assert False = next.member_task_show_edit_in_flight
  let assert None = next.member_task_show_edit_error
}
