import gleam/option.{None, Some}

import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/show_permissions

pub fn current_user_can_edit_available_task_test() {
  let assert True =
    show_permissions.can_edit(Some(7), task(task_state.Available))
}

pub fn anonymous_user_cannot_edit_available_task_test() {
  let assert False = show_permissions.can_edit(None, task(task_state.Available))
}

pub fn claimant_can_edit_claimed_task_test() {
  let assert True = show_permissions.can_edit(Some(7), task(claimed_by(7)))
}

pub fn other_user_cannot_edit_claimed_task_test() {
  let assert False = show_permissions.can_edit(Some(8), task(claimed_by(7)))
}

pub fn completed_task_is_read_only_for_claimant_test() {
  let assert False =
    show_permissions.can_edit(
      Some(7),
      task(task_state.Done("2026-06-14T12:00:00Z")),
    )
}

fn claimed_by(user_id: Int) -> task_state.TaskState {
  task_state.Claimed(
    claimed_by: user_id,
    claimed_at: "2026-03-20T15:00:00Z",
    mode: task_status.Taken,
  )
}

fn task(state: task_state.TaskState) -> Task {
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
