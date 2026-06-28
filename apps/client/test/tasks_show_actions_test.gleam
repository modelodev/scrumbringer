import gleam/option.{None, Some}
import support/domain_fixtures

import domain/task.{type Task, Task}
import domain/task/state as task_state
import scrumbringer_client/features/tasks/show/actions as task_show_actions

pub fn primary_action_claims_available_unblocked_task_test() {
  let assert task_show_actions.ClaimTask(42, 3) =
    task_show_actions.primary_action(Some(available_task()), Some(7), False)
}

pub fn primary_action_explains_blocked_available_task_test() {
  let assert task_show_actions.NoPrimaryAction(
    task_show_actions.BlockedByDependencies,
  ) =
    task_show_actions.primary_action(
      Some(Task(..available_task(), blocked_count: 1)),
      Some(7),
      False,
    )
}

pub fn primary_action_starts_task_claimed_by_current_user_test() {
  let assert task_show_actions.StartWork(42) =
    task_show_actions.primary_action(Some(claimed_task(7)), Some(7), False)
}

pub fn primary_action_closes_ongoing_task_for_current_user_test() {
  let assert task_show_actions.CloseTask(42, 3) =
    task_show_actions.primary_action(Some(ongoing_task(7)), Some(7), False)
}

pub fn primary_action_explains_task_claimed_by_another_user_test() {
  let assert task_show_actions.NoPrimaryAction(
    task_show_actions.ClaimedByAnotherUser,
  ) = task_show_actions.primary_action(Some(claimed_task(9)), Some(7), False)
}

pub fn can_release_only_when_claimed_by_current_user_test() {
  let assert True = task_show_actions.can_release(claimed_task(7), Some(7))
  let assert False = task_show_actions.can_release(claimed_task(9), Some(7))
  let assert False = task_show_actions.can_release(available_task(), Some(7))
  let assert False = task_show_actions.can_release(claimed_task(7), None)
}

fn available_task() -> Task {
  Task(..domain_fixtures.task(42, "Prepare release", 1), version: 3)
}

fn claimed_task(claimed_by: Int) -> Task {
  Task(
    ..available_task(),
    state: task_state.Claimed(
      claimed_by: claimed_by,
      claimed_at: "2026-06-01T11:00:00Z",
      mode: task_state.Taken,
    ),
  )
}

fn ongoing_task(claimed_by: Int) -> Task {
  Task(
    ..available_task(),
    state: task_state.Claimed(
      claimed_by: claimed_by,
      claimed_at: "2026-06-01T11:00:00Z",
      mode: task_state.Ongoing,
    ),
  )
}
