import gleam/int
import gleam/option.{None, Some}

import domain/remote.{Loaded, Loading}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
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
      task_state.Claimed(claimed_by: 7, claimed_at: "", mode: task_status.Taken),
    )
  let assert task_state.Claimed(
    claimed_by: 7,
    claimed_at: "",
    mode: task_status.Taken,
  ) = updated.state
}

fn sample_task(id: Int) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: None,
    title: "Task " <> int.to_string(id),
    description: None,
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
