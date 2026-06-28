import gleam/option.{None, Some}
import support/domain_fixtures

import domain/task.{type Task, Task}
import domain/task/state as task_state
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

pub fn closed_task_is_read_only_for_claimant_test() {
  let assert False =
    show_permissions.can_edit(
      Some(7),
      task(task_state.Closed(
        task_state.ClosedByClaimant,
        "2026-06-14T12:00:00Z",
        7,
      )),
    )
}

fn claimed_by(user_id: Int) -> task_state.TaskExecutionState {
  task_state.Claimed(
    claimed_by: user_id,
    claimed_at: "2026-03-20T15:00:00Z",
    mode: task_state.Taken,
  )
}

fn task(state: task_state.TaskExecutionState) -> Task {
  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    description: Some("Review release checklist."),
    priority: 2,
    state: state,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
  )
}
