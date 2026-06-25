import gleam/option.{None, Some}

import domain/remote
import domain/task.{type Task, Task, with_state}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/mutation_state

fn sample_task(id: Int, state: task_state.TaskExecutionState) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Review checklist."),
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

fn pool_with_tasks(tasks: List(Task)) -> member_pool.Model {
  member_pool.Model(
    ..member_pool.default_model(),
    member_tasks: remote.Loaded(tasks),
  )
}

pub fn mutation_state_start_claim_snapshots_and_sets_claimed_state_test() {
  let task = sample_task(42, task_state.Available)

  let next = mutation_state.start_claim(pool_with_tasks([task]), 42, Some(7))
  let expected = remote.Loaded([claimed_task(task, 7)])

  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert True = next.member_tasks_snapshot == Some([task])
  let assert True = next.member_tasks == expected
}

pub fn mutation_state_start_claim_without_user_keeps_tasks_test() {
  let task = sample_task(42, task_state.Available)

  let next = mutation_state.start_claim(pool_with_tasks([task]), 42, None)
  let expected = remote.Loaded([task])

  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert True = next.member_tasks_snapshot == Some([task])
  let assert True = next.member_tasks == expected
}

pub fn mutation_state_start_release_sets_available_state_test() {
  let task =
    sample_task(
      42,
      task_state.Claimed(
        claimed_by: 7,
        claimed_at: "2026-03-20T15:00:00Z",
        mode: task_state.Taken,
      ),
    )

  let next = mutation_state.start_release(pool_with_tasks([task]), 42)
  let expected = remote.Loaded([sample_task(42, task_state.Available)])

  let assert True = next.member_tasks == expected
  let assert True = next.member_task_mutation_in_flight
  let assert True = next.member_tasks_snapshot == Some([task])
}

pub fn mutation_state_start_complete_sets_closed_state_test() {
  let task =
    sample_task(
      42,
      task_state.Claimed(
        claimed_by: 7,
        claimed_at: "2026-03-20T15:00:00Z",
        mode: task_state.Taken,
      ),
    )

  let next = mutation_state.start_complete(pool_with_tasks([task]), 42, Some(7))
  let expected =
    remote.Loaded([sample_task(42, task_state.Closed(task_state.Done, "", 7))])

  let assert True = next.member_tasks == expected
  let assert True = next.member_task_mutation_in_flight
  let assert True = next.member_tasks_snapshot == Some([task])
}

pub fn mutation_state_restore_and_clear_restores_snapshot_test() {
  let original = sample_task(42, task_state.Available)
  let optimistic = claimed_task(original, 7)
  let model =
    member_pool.Model(
      ..pool_with_tasks([optimistic]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
      member_tasks_snapshot: Some([original]),
    )

  let next = mutation_state.restore_and_clear(model)
  let expected = remote.Loaded([original])

  let assert True = next.member_tasks == expected
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
}

pub fn mutation_state_start_dropped_claim_does_not_snapshot_test() {
  let task = sample_task(42, task_state.Available)

  let next = mutation_state.start_dropped_claim(pool_with_tasks([task]))
  let expected = remote.Loaded([task])

  let assert True = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = next.member_tasks == expected
}

fn claimed_task(task: Task, user_id: Int) -> Task {
  with_state(
    task,
    task_state.Claimed(
      claimed_by: user_id,
      claimed_at: "",
      mode: task_state.Taken,
    ),
  )
}
