//// Shared task state rollups for work surfaces.

import domain/task as domain_task
import domain/task/state as task_execution_state
import gleam/list

pub type TaskRollup {
  TaskRollup(
    total: Int,
    available: Int,
    claimed: Int,
    ongoing: Int,
    closed: Int,
    blocked: Int,
  )
}

pub fn from_tasks(tasks: List(domain_task.Task)) -> TaskRollup {
  TaskRollup(
    total: list.length(tasks),
    available: list.count(tasks, is_available),
    claimed: list.count(tasks, is_taken),
    ongoing: list.count(tasks, is_ongoing),
    closed: list.count(tasks, is_closed),
    blocked: list.count(tasks, is_blocked),
  )
}

pub fn is_available(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Available -> True
    _ -> False
  }
}

pub fn is_available_unblocked(task: domain_task.Task) -> Bool {
  is_available(task) && !is_blocked(task)
}

pub fn is_taken(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Claimed(mode: task_execution_state.Taken, ..) -> True
    _ -> False
  }
}

pub fn is_taken_unblocked(task: domain_task.Task) -> Bool {
  is_taken(task) && !is_blocked(task)
}

pub fn is_ongoing(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Claimed(mode: task_execution_state.Ongoing, ..) -> True
    _ -> False
  }
}

pub fn is_ongoing_unblocked(task: domain_task.Task) -> Bool {
  is_ongoing(task) && !is_blocked(task)
}

pub fn is_closed(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Closed(..) -> True
    _ -> False
  }
}

pub fn is_blocked(task: domain_task.Task) -> Bool {
  task.blocked_count > 0
}

pub fn work_rank(task: domain_task.Task) -> Int {
  case is_blocked(task), task.state {
    True, _ -> 0
    False, task_execution_state.Available -> 1
    False, task_execution_state.Claimed(mode: task_execution_state.Ongoing, ..) ->
      2
    False, task_execution_state.Claimed(mode: task_execution_state.Taken, ..) ->
      3
    False, task_execution_state.Closed(..) -> 4
  }
}
