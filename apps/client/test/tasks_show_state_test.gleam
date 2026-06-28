import gleam/option.{None, Some}
import support/domain_fixtures

import domain/remote
import domain/task.{type Task, Task}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/features/tasks/show/model as task_show_model
import scrumbringer_client/features/tasks/show_edit_form
import scrumbringer_client/features/tasks/show_state
import scrumbringer_client/ui/show_tabs

fn sample_task() -> Task {
  Task(
    ..domain_fixtures.task(42, "Prepare release", 7),
    description: Some("Review checklist."),
    priority: 4,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
    parent_card_id: Some(12),
    card_id: Some(9),
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
  let #(task_show, notes, dependencies) =
    show_state.open(
      task_show_model.default(),
      member_notes.default_model(),
      member_dependencies.default_model(),
      42,
      Some(sample_task()),
    )

  let assert show_tabs.TaskDetailsTab = task_show.active_tab
  let assert "Prepare release" = task_show.edit_title
  let assert "Review checklist." = task_show.edit_description
  let assert "4" = task_show.edit_priority
  let assert "7" = task_show.edit_type_id
  let assert "9" = task_show.edit_card_id
  let assert Some(42) = notes.member_notes_task_id
  let assert True = notes.member_notes == remote.Loading
  let assert True = dependencies.member_dependencies == remote.Loading
}

pub fn show_state_open_uses_inline_task_type_when_type_id_is_invalid_test() {
  let task = Task(..sample_task(), type_id: 0)
  let #(task_show, _, _) =
    show_state.open(
      task_show_model.default(),
      member_notes.default_model(),
      member_dependencies.default_model(),
      42,
      Some(task),
    )

  let assert "7" = task_show.edit_type_id
}

pub fn show_state_close_resets_show_state_test() {
  let notes =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes_task_id: Some(42),
      member_notes: remote.Loading,
      member_note_content: "draft",
      member_note_dialog_mode: dialog_mode.DialogCreate,
    )

  let #(task_show, next_notes, next_dependencies) = show_state.close(notes)

  let assert show_tabs.TaskDetailsTab = task_show.active_tab
  let assert False = task_show.editing
  let assert "" = task_show.edit_title
  let assert "" = task_show.edit_description
  let assert None = next_notes.member_notes_task_id
  let assert True = next_notes.member_notes == remote.NotAsked
  let assert "" = next_notes.member_note_content
  let assert dialog_mode.DialogClosed = next_notes.member_note_dialog_mode
  let assert True = next_dependencies == member_dependencies.default_model()
}

pub fn show_state_start_edit_sets_canonical_task_values_test() {
  let next =
    show_state.start_edit(task_show_model.default(), Some(sample_task()), True)

  let assert True = next.editing
  let assert "Prepare release" = next.edit_title
  let assert "Review checklist." = next.edit_description
  let assert None = next.edit_error
}

pub fn show_state_start_edit_ignores_disallowed_task_test() {
  let model = task_show_model.default()
  let next = show_state.start_edit(model, Some(sample_task()), False)

  let assert True = next == model
}

pub fn show_state_edit_decisions_update_form_state_test() {
  let invalid = show_state.edit_invalid(task_show_model.default(), "Required")
  let unchanged =
    show_state.edit_unchanged(
      task_show_model.Model(..invalid, editing: True),
      submission("Prepare release", "Review checklist."),
    )
  let started =
    show_state.edit_started_submit(
      task_show_model.default(),
      submission("Updated", "Updated description"),
    )

  let assert Some("Required") = invalid.edit_error
  let assert False = unchanged.editing
  let assert "Prepare release" = unchanged.edit_title
  let assert "2" = unchanged.edit_priority
  let assert "1" = unchanged.edit_type_id
  let assert None = unchanged.edit_error
  let assert True = started.edit_in_flight
  let assert "Updated" = started.edit_title
}

pub fn show_state_task_updated_stops_editing_test() {
  let original = sample_task()
  let updated =
    Task(
      ..original,
      title: "Updated title",
      description: Some("Updated description"),
      version: 4,
    )
  let model =
    task_show_model.Model(
      ..task_show_model.default(),
      editing: True,
      edit_in_flight: True,
      edit_error: Some("old"),
    )

  let next = show_state.task_updated(model, updated)

  let assert True = original.id == updated.id
  let assert False = next.editing
  let assert "Updated title" = next.edit_title
  let assert "Updated description" = next.edit_description
  let assert False = next.edit_in_flight
  let assert None = next.edit_error
}
