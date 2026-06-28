import support/domain_fixtures

import domain/task.{type Task, Task}
import domain/task/state as task_state
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
        mode: task_state.Taken,
      ),
      0,
    ))
}

pub fn closed_task_cannot_be_claimed_test() {
  let assert False =
    claimability.can_claim(sample_task(
      task_state.Closed(task_state.ClosedByClaimant, "2026-06-01T12:00:00Z", 7),
      0,
    ))
}

fn sample_task(state: task_state.TaskExecutionState, blocked_count: Int) -> Task {
  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    priority: 2,
    state: state,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    blocked_count: blocked_count,
  )
}
