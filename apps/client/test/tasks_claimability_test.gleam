import gleam/option.{None}

import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status.{Taken}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/claimability

pub fn available_unblocked_task_can_be_claimed_test() {
  let assert True = claimability.can_claim(sample_task(task_state.Available, 0))
}

pub fn blocked_available_task_cannot_be_claimed_test() {
  let assert False =
    claimability.can_claim(sample_task(task_state.Available, 1))
}

pub fn claimed_task_cannot_be_claimed_test() {
  let assert False =
    claimability.can_claim(sample_task(
      task_state.Claimed(
        claimed_by: 7,
        claimed_at: "2026-06-01T11:00:00Z",
        mode: Taken,
      ),
      0,
    ))
}

pub fn completed_task_cannot_be_claimed_test() {
  let assert False =
    claimability.can_claim(sample_task(
      task_state.Done(completed_at: "2026-06-01T12:00:00Z"),
      0,
    ))
}

fn sample_task(state: task_state.TaskState, blocked_count: Int) -> Task {
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Prepare release",
    description: None,
    priority: 2,
    state: state,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: blocked_count,
    dependencies: [],
  )
}
