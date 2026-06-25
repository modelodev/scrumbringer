//// Pure permissions for Task Show interactions.

import gleam/option as opt

import domain/task.{type Task}
import domain/task/state as task_state

pub fn can_edit(current_user_id: opt.Option(Int), current_task: Task) -> Bool {
  case current_task.state {
    task_state.Closed(task_state.Done, _, _) -> False
    _ -> can_edit_open_task(current_user_id, current_task)
  }
}

fn can_edit_open_task(
  current_user_id: opt.Option(Int),
  current_task: Task,
) -> Bool {
  case current_user_id, task_state.claimed_by(current_task.state) {
    opt.Some(user_id), opt.Some(claimed_by) -> user_id == claimed_by
    opt.Some(_), opt.None -> True
    _, _ -> False
  }
}
