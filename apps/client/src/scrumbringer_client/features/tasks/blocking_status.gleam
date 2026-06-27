//// Shared task blocking predicates for UI surfaces.

import gleam/list

import domain/task.{type Task}

pub fn is_blocked(task: Task) -> Bool {
  task.blocked_count > 0
}

pub fn blocked_count(tasks: List(Task)) -> Int {
  tasks
  |> list.filter(is_blocked)
  |> list.length
}
