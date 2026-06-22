import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element

import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status.{Ongoing, Taken}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_show_footer
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn task_show_footer_renders_close_only_without_task_test() {
  let html =
    task_show_footer.view(config(None, current_user_id: Some(7)))
    |> element.to_document_string

  assert_contains(html, "task-show-footer")
  assert_contains(html, "task-action-bar")
  assert_not_contains(html, ">Close<")
  assert_not_contains(html, "Claim task")
  assert_not_contains(html, "Release")
  assert_not_contains(html, "Complete")
}

pub fn task_show_footer_disables_claim_for_blocked_task_test() {
  let html =
    task_show_footer.view(config(
      Some(Task(..available_task(), blocked_count: 1)),
      current_user_id: Some(7),
    ))
    |> element.to_document_string

  assert_contains(html, "Claim task")
  assert_contains(html, "data-testid=\"secondary-actions-menu\"")
  assert_contains(html, "data-testid=\"task-show-secondary-delete\"")
  assert_contains(html, "data-tooltip=\"Task has incomplete dependencies\"")
  assert_contains(html, "aria-disabled=\"true\"")
  assert_contains(html, "data-testid=\"task-show-primary-claim\"")
  assert_not_contains(html, "Release")
  assert_not_contains(html, "Complete")
}

pub fn task_show_footer_renders_owner_claimed_actions_test() {
  let html =
    task_show_footer.view(config(
      Some(claimed_task(claimed_by: 7)),
      current_user_id: Some(7),
    ))
    |> element.to_document_string

  assert_not_contains(html, ">Close<")
  assert_not_contains(html, "data-testid=\"task-show-primary-complete\"")
  assert_contains(html, "Start working")
  assert_contains(html, "data-testid=\"task-show-primary-start\"")
  assert_contains(html, "data-testid=\"task-show-secondary-delete\"")
  assert_contains(
    html,
    "title=\"This task has operational history. Close it instead of deleting it.\"",
  )
  assert_contains(html, "Release back to Pool")
  assert_not_contains(html, "Claim task")
}

pub fn task_show_footer_renders_owner_ongoing_complete_as_primary_test() {
  let html =
    task_show_footer.view(config(
      Some(ongoing_task(claimed_by: 7)),
      current_user_id: Some(7),
    ))
    |> element.to_document_string

  assert_contains(html, "Complete task")
  assert_contains(html, "data-testid=\"task-show-primary-complete\"")
  assert_contains(html, "Release back to Pool")
  assert_not_contains(html, "Start working")
  assert_not_contains(html, ">Close<")
}

pub fn task_show_footer_hides_claimed_actions_for_other_owner_test() {
  let html =
    task_show_footer.view(config(
      Some(claimed_task(claimed_by: 9)),
      current_user_id: Some(7),
    ))
    |> element.to_document_string

  assert_not_contains(html, ">Close<")
  assert_contains(html, "data-testid=\"task-show-secondary-delete\"")
  assert_not_contains(html, "Start working")
  assert_not_contains(html, "Release")
  assert_not_contains(html, "Complete")
}

pub fn task_show_footer_renders_edit_actions_in_edit_mode_test() {
  let html =
    task_show_footer.view(
      task_show_footer.Config(
        ..config(Some(claimed_task(claimed_by: 7)), current_user_id: Some(7)),
        editing: True,
        edit_dirty: True,
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Cancel")
  assert_contains(html, "Save")
  assert_not_contains(html, "Release")
  assert_not_contains(html, "Complete")
}

pub fn task_show_footer_disables_save_without_edit_changes_test() {
  let html =
    task_show_footer.view(
      task_show_footer.Config(
        ..config(Some(claimed_task(claimed_by: 7)), current_user_id: Some(7)),
        editing: True,
        edit_dirty: False,
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Save")
  assert_contains(html, "disabled")
}

fn config(
  task_value: Option(Task),
  current_user_id current_user_id_value: Option(Int),
) -> task_show_footer.Config(String) {
  task_show_footer.Config(
    locale: locale.En,
    task: task_value,
    current_user_id: current_user_id_value,
    disable_actions: False,
    editing: False,
    edit_in_flight: False,
    edit_dirty: False,
    on_close: "close",
    on_edit_cancelled: "cancel-edit",
    on_edit_submitted: "submit-edit",
    on_claim: fn(_, _) { "claim" },
    on_start_work: fn(_) { "start-work" },
    on_release: fn(_, _) { "release" },
    on_complete: fn(_, _) { "complete" },
    on_delete: fn(_) { "delete" },
  )
}

fn available_task() -> Task {
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Task description"),
    priority: 2,
    state: task_state.Available,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn claimed_task(claimed_by claimed_by: Int) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: claimed_by,
      claimed_at: "2026-06-01T11:00:00Z",
      mode: Taken,
    )

  Task(..available_task(), state: state)
}

fn ongoing_task(claimed_by claimed_by: Int) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: claimed_by,
      claimed_at: "2026-06-01T11:00:00Z",
      mode: Ongoing,
    )

  Task(..available_task(), state: state)
}
