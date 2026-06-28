import domain/task.{type Task, Task}
import domain/task/state as task_state
import support/domain_fixtures

import scrumbringer_client/features/tasks/rollup

pub fn rollup_counts_task_execution_states_test() {
  let tasks = [
    available_task(1),
    claimed_task(2, task_state.Taken),
    claimed_task(3, task_state.Ongoing),
    closed_task(4),
    Task(..available_task(5), blocked_count: 2),
  ]

  let summary = rollup.from_tasks(tasks)

  let assert 5 = summary.total
  let assert 2 = summary.available
  let assert 1 = summary.claimed
  let assert 1 = summary.ongoing
  let assert 1 = summary.closed
  let assert 1 = summary.blocked
  let assert 1 = rollup.blocked_count(tasks)
}

pub fn predicates_use_canonical_task_state_test() {
  let assert True = rollup.is_available(available_task(1))
  let assert True = rollup.is_taken(claimed_task(2, task_state.Taken))
  let assert True = rollup.is_ongoing(claimed_task(3, task_state.Ongoing))
  let assert True = rollup.is_closed(closed_task(4))
  let assert True =
    rollup.is_blocked(Task(..available_task(5), blocked_count: 1))
}

pub fn unblocked_predicates_exclude_blocked_tasks_test() {
  let assert [True, False, True, False, True, False] = [
    rollup.is_available_unblocked(available_task(1)),
    rollup.is_available_unblocked(Task(..available_task(2), blocked_count: 1)),
    rollup.is_taken_unblocked(claimed_task(3, task_state.Taken)),
    rollup.is_taken_unblocked(
      Task(..claimed_task(4, task_state.Taken), blocked_count: 1),
    ),
    rollup.is_ongoing_unblocked(claimed_task(5, task_state.Ongoing)),
    rollup.is_ongoing_unblocked(
      Task(..claimed_task(6, task_state.Ongoing), blocked_count: 1),
    ),
  ]
}

pub fn work_rank_prioritizes_visible_work_order_test() {
  let assert [0, 1, 2, 3, 4] = [
    rollup.work_rank(Task(..closed_task(1), blocked_count: 1)),
    rollup.work_rank(available_task(2)),
    rollup.work_rank(claimed_task(3, task_state.Ongoing)),
    rollup.work_rank(claimed_task(4, task_state.Taken)),
    rollup.work_rank(closed_task(5)),
  ]
}

fn available_task(id: Int) -> Task {
  domain_fixtures.task(id, "Task", 1)
}

fn claimed_task(id: Int, mode: task_state.TaskClaimMode) -> Task {
  Task(
    ..available_task(id),
    state: task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-06-01T10:00:00Z",
      mode: mode,
    ),
  )
}

fn closed_task(id: Int) -> Task {
  Task(
    ..available_task(id),
    state: task_state.Closed(
      reason: task_state.ClosedByClaimant,
      closed_at: "2026-06-01T11:00:00Z",
      closed_by: 7,
    ),
  )
}
