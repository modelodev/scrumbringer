import domain/task.{type Task, Task}
import support/domain_fixtures

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
  Task(..domain_fixtures.task(id, "Task", 1), blocked_count: blocked_count)
}
