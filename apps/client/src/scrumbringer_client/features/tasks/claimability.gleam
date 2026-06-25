//// Shared task claimability rules for client UI and mutations.

import domain/task.{type Task}
import domain/task/state as task_state

pub fn can_claim(task: Task) -> Bool {
  case task.state, task.blocked_count {
    task_state.Available, 0 -> True
    _, _ -> False
  }
}
