import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import gleam/option as opt

import scrumbringer_client/features/tasks/blocking_status

pub fn blocked_count_counts_only_tasks_with_open_blockers_test() {
  let tasks = [
    task(1, 0),
    task(2, 1),
    task(3, 3),
  ]

  let assert 2 = blocking_status.blocked_count(tasks)
}

pub fn is_blocked_uses_open_blocker_count_test() {
  let assert False = blocking_status.is_blocked(task(1, 0))
  let assert True = blocking_status.is_blocked(task(2, 1))
}

fn task(id: Int, blocked_count: Int) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "clipboard"),
    ongoing_by: opt.None,
    title: "Task",
    description: opt.None,
    priority: 2,
    state: task_state.Available,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    version: 1,
    parent_card_id: opt.None,
    card_id: opt.None,
    card_title: opt.None,
    card_color: opt.None,
    has_new_notes: False,
    blocked_count: blocked_count,
    dependencies: [],
    automation_origin: opt.None,
  )
}
