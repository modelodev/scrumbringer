import gleam/option.{None, Some}

import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/detail_state
import scrumbringer_client/ui/task_tabs

fn sample_task() -> Task {
  let state = task_state.Available
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Review checklist."),
    priority: 2,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

pub fn detail_state_open_sets_loading_detail_state_test() {
  let #(pool, notes, dependencies) =
    detail_state.open(
      member_pool.default_model(),
      member_notes.default_model(),
      member_dependencies.default_model(),
      42,
      "Prepare release",
      "Review checklist.",
    )

  let assert task_tabs.TasksTab = pool.member_task_detail_tab
  let assert True = pool.member_task_detail_metrics == remote.Loading
  let assert "Prepare release" = pool.member_task_detail_edit_title
  let assert "Review checklist." = pool.member_task_detail_edit_description
  let assert Some(42) = notes.member_notes_task_id
  let assert True = notes.member_notes == remote.Loading
  let assert True = dependencies.member_dependencies == remote.Loading
}

pub fn detail_state_close_resets_detail_state_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_tab: task_tabs.MetricsTab,
      member_task_detail_metrics: remote.Loading,
      member_task_detail_editing: True,
      member_task_detail_edit_title: "Changed",
      member_task_detail_edit_description: "Changed description",
      member_task_detail_edit_in_flight: True,
      member_task_detail_edit_error: Some("old"),
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
    detail_state.close(pool, notes)

  let assert task_tabs.TasksTab = next_pool.member_task_detail_tab
  let assert True = next_pool.member_task_detail_metrics == remote.NotAsked
  let assert False = next_pool.member_task_detail_editing
  let assert "" = next_pool.member_task_detail_edit_title
  let assert "" = next_pool.member_task_detail_edit_description
  let assert None = next_notes.member_notes_task_id
  let assert True = next_notes.member_notes == remote.NotAsked
  let assert "" = next_notes.member_note_content
  let assert dialog_mode.DialogClosed = next_notes.member_note_dialog_mode
  let assert True = next_dependencies == member_dependencies.default_model()
}

pub fn detail_state_start_edit_sets_canonical_task_values_test() {
  let next =
    detail_state.start_edit(
      member_pool.default_model(),
      Some(sample_task()),
      True,
    )

  let assert True = next.member_task_detail_editing
  let assert "Prepare release" = next.member_task_detail_edit_title
  let assert "Review checklist." = next.member_task_detail_edit_description
  let assert None = next.member_task_detail_edit_error
}

pub fn detail_state_start_edit_ignores_disallowed_task_test() {
  let model = member_pool.default_model()
  let next = detail_state.start_edit(model, Some(sample_task()), False)

  let assert True = next == model
}

pub fn detail_state_edit_decisions_update_form_state_test() {
  let invalid =
    detail_state.edit_invalid(member_pool.default_model(), "Required")
  let unchanged =
    detail_state.edit_unchanged(
      member_pool.Model(..invalid, member_task_detail_editing: True),
      "Prepare release",
      "Review checklist.",
    )
  let started =
    detail_state.edit_started_submit(
      member_pool.default_model(),
      "Updated",
      "Updated description",
    )

  let assert Some("Required") = invalid.member_task_detail_edit_error
  let assert False = unchanged.member_task_detail_editing
  let assert "Prepare release" = unchanged.member_task_detail_edit_title
  let assert None = unchanged.member_task_detail_edit_error
  let assert True = started.member_task_detail_edit_in_flight
  let assert "Updated" = started.member_task_detail_edit_title
}

pub fn detail_state_task_updated_replaces_task_and_stops_editing_test() {
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
      member_task_detail_editing: True,
      member_task_detail_edit_in_flight: True,
      member_task_detail_edit_error: Some("old"),
    )

  let next = detail_state.task_updated(model, updated)

  let assert True = next.member_tasks == remote.Loaded([updated])
  let assert False = next.member_task_detail_editing
  let assert "Updated title" = next.member_task_detail_edit_title
  let assert "Updated description" = next.member_task_detail_edit_description
  let assert False = next.member_task_detail_edit_in_flight
  let assert None = next.member_task_detail_edit_error
}
