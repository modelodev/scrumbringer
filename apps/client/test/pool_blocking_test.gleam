import gleam/option.{None, Some}
import support/domain_fixtures

import domain/remote.{Loaded, NotAsked}
import domain/task.{type TaskDependency, Task, TaskDependency}
import domain/task/state as task_state
import scrumbringer_client/features/pool/blocking

pub fn open_dependencies_excludes_closed_dependencies_test() {
  let task =
    sample_task(1, [
      dependency(2, task_state.Available),
      dependency(3, closed_done_state()),
    ])

  let assert [dep] = blocking.open_dependencies(task)
  let assert 2 = dep.depends_on_task_id
  let assert [2] = blocking.open_dependency_ids(task)
  let assert 1 =
    blocking.open_dependency_count([
      dependency(2, task_state.Available),
      dependency(3, closed_done_state()),
    ])
}

pub fn open_dependencies_or_empty_defaults_missing_task_test() {
  let assert [] = blocking.open_dependencies_or_empty(None)

  let task = sample_task(1, [dependency(2, task_state.Available)])
  let assert [dep] = blocking.open_dependencies_or_empty(Some(task))
  let assert 2 = dep.depends_on_task_id
}

pub fn hidden_count_counts_blockers_not_present_in_loaded_tasks_test() {
  let visible = sample_task(2, [])

  let assert 1 = blocking.hidden_count(Loaded([visible]), [2, 3])
  let assert 2 = blocking.hidden_count(NotAsked, [2, 3])
}

fn dependency(id: Int, state: task_state.TaskExecutionState) -> TaskDependency {
  TaskDependency(..domain_fixtures.dependency(id), state: state)
}

fn closed_done_state() -> task_state.TaskExecutionState {
  task_state.Closed(task_state.ClosedByClaimant, "2026-06-01T10:00:00Z", 7)
}

fn sample_task(id: Int, dependencies: List(TaskDependency)) {
  Task(..domain_fixtures.task(id, "Task", 1), dependencies: dependencies)
}
