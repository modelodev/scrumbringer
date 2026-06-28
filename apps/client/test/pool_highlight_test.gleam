import support/domain_fixtures

import domain/remote.{Loaded}
import domain/task.{type Task, type TaskDependency, Task}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/highlight

fn default_pool() -> member_pool.Model {
  member_pool.default_model()
}

fn make_dependency(depends_on_task_id: Int) -> TaskDependency {
  domain_fixtures.dependency(depends_on_task_id)
}

fn make_task(id: Int, dependencies: List(TaskDependency)) -> Task {
  Task(..domain_fixtures.task(id, "Task", 1), dependencies: dependencies)
}

pub fn blocking_for_task_sets_hidden_count_for_missing_blockers_test() {
  let source = make_task(1, [make_dependency(2)])
  let pool =
    member_pool.Model(..default_pool(), member_tasks: Loaded([source]))
    |> highlight.blocking_for_task(1)

  let assert member_pool.BlockingHighlight(1, [2], 1) =
    pool.member_highlight_state
}

pub fn blocking_for_task_sets_zero_hidden_count_for_visible_blockers_test() {
  let source = make_task(1, [make_dependency(2)])
  let blocker = make_task(2, [])
  let pool =
    member_pool.Model(..default_pool(), member_tasks: Loaded([source, blocker]))
    |> highlight.blocking_for_task(1)

  let assert member_pool.BlockingHighlight(1, [2], 0) =
    pool.member_highlight_state
}

pub fn blocking_for_task_clears_highlight_for_unblocked_task_test() {
  let source = make_task(1, [])
  let pool =
    member_pool.Model(
      ..default_pool(),
      member_tasks: Loaded([source]),
      member_highlight_state: member_pool.BlockingHighlight(9, [10], 0),
    )
    |> highlight.blocking_for_task(1)

  let assert member_pool.NoHighlight = pool.member_highlight_state
}

pub fn clear_resets_any_highlight_test() {
  let pool =
    member_pool.Model(
      ..default_pool(),
      member_highlight_state: member_pool.BlockingHighlight(9, [10], 0),
    )
    |> highlight.clear

  let assert member_pool.NoHighlight = pool.member_highlight_state
}

pub fn created_sets_created_highlight_test() {
  let pool = highlight.created(default_pool(), 21)

  let assert member_pool.CreatedHighlight(21) = pool.member_highlight_state
}

pub fn expire_clears_matching_created_highlight_only_test() {
  let matching =
    member_pool.Model(
      ..default_pool(),
      member_highlight_state: member_pool.CreatedHighlight(21),
    )
    |> highlight.expire(21)
  let different =
    member_pool.Model(
      ..default_pool(),
      member_highlight_state: member_pool.CreatedHighlight(22),
    )
    |> highlight.expire(21)

  let assert member_pool.NoHighlight = matching.member_highlight_state
  let assert member_pool.CreatedHighlight(22) = different.member_highlight_state
}
