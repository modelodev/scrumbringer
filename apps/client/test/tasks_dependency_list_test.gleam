import gleam/option.{None, Some}

import domain/remote.{Loaded, Loading}
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/dependency_list

pub fn add_to_remote_starts_loaded_list_when_not_loaded_test() {
  let dep = sample_dependency(11, task_state.Available)

  let assert True = dependency_list.add_to_remote(Loading, dep) == Loaded([dep])
}

pub fn remove_from_remote_removes_dependency_and_reports_blocked_delta_test() {
  let first = sample_dependency(10, task_state.Available)
  let second = sample_dependency(11, closed_done_state())

  let assert True =
    dependency_list.remove_from_remote(Loaded([first, second]), 10)
    == #(Loaded([second]), 1)
}

pub fn remove_from_remote_reports_zero_delta_for_closed_or_missing_test() {
  let closed = sample_dependency(10, closed_done_state())

  let assert True =
    dependency_list.remove_from_remote(Loaded([closed]), 10) == #(Loaded([]), 0)
  let assert True =
    dependency_list.remove_from_remote(Loaded([closed]), 99)
    == #(Loaded([closed]), 0)
}

pub fn add_to_task_increments_blocked_count_only_for_open_dependency_test() {
  let task = sample_task()
  let blocker = sample_dependency(10, task_state.Available)
  let closed = sample_dependency(11, closed_done_state())

  let assert True =
    dependency_list.add_to_task(task, blocker)
    == Task(..task, blocked_count: 1, dependencies: [blocker])
  let assert True =
    dependency_list.add_to_task(task, closed)
    == Task(..task, blocked_count: 0, dependencies: [closed])
}

pub fn remove_from_task_clamps_blocked_count_test() {
  let blocker = sample_dependency(10, task_state.Available)
  let task = Task(..sample_task(), dependencies: [blocker], blocked_count: 0)

  let assert Task(blocked_count: 0, dependencies: [], ..) =
    dependency_list.remove_from_task(task, 10, 1)
}

fn sample_dependency(
  depends_on_task_id: Int,
  state: task_state.TaskExecutionState,
) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: "Dependency",
    state: state,
    claimed_by: None,
  )
}

fn closed_done_state() -> task_state.TaskExecutionState {
  task_state.Closed(task_state.Done, "2026-06-01T10:00:00Z", 7)
}

fn sample_task() -> Task {
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: None,
    title: "Task",
    description: Some("Details"),
    priority: 1,
    state: task_state.Available,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
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
