//// Shared task blocking predicates for UI surfaces.

import gleam/list

import domain/task.{type Task}
import scrumbringer_client/features/tasks/rollup

pub fn is_blocked(task: Task) -> Bool {
  rollup.is_blocked(task)
}

pub fn blocked_count(tasks: List(Task)) -> Int {
  list.count(tasks, rollup.is_blocked)
}
