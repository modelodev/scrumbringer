//// Shared task claimability rules for client UI and mutations.

import domain/task.{type Task}
import domain/task/state as task_state
import domain/task_status

pub fn can_claim(task: Task) -> Bool {
  case task_state.to_work_state(task.state), task.blocked_count {
    task_status.WorkAvailable, 0 -> True
    _, _ -> False
  }
}
