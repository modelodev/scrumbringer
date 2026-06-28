import gleam/int
import gleam/option.{None, Some}
import support/domain_fixtures

import domain/remote.{Loaded, Loading}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import scrumbringer_client/features/tasks/task_list

pub fn snapshot_returns_loaded_tasks_only_test() {
  let task = sample_task(1)

  let assert Some([_task]) = task_list.snapshot(Loaded([task]))
  let assert None = task_list.snapshot(Loading)
}

pub fn update_changes_only_matching_task_test() {
  let tasks = Loaded([sample_task(1), sample_task(2)])

  let assert Loaded([first, second]) =
    task_list.update(tasks, 2, fn(task) { Task(..task, title: "Updated") })
  let assert "Task 1" = first.title
  let assert "Updated" = second.title
}

pub fn replace_keeps_remote_state_when_not_loaded_test() {
  let assert Loading = task_list.replace(Loading, sample_task(1))
}

pub fn set_state_updates_matching_task_test() {
  let tasks = Loaded([sample_task(1)])

  let assert Loaded([updated]) =
    task_list.set_state(
      tasks,
      1,
      task_state.Claimed(claimed_by: 7, claimed_at: "", mode: task_state.Taken),
    )
  let assert task_state.Claimed(
    claimed_by: 7,
    claimed_at: "",
    mode: task_state.Taken,
  ) = updated.state
}

fn sample_task(id: Int) -> Task {
  domain_fixtures.task(id, "Task " <> int.to_string(id), 1)
}
