//// Pure task dependency transformations for local task detail state.

import gleam/list
import gleam/option as opt

import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, type TaskDependency, Task}
import domain/task_status.{Completed}

pub fn add_to_remote(
  deps: Remote(List(TaskDependency)),
  dep: TaskDependency,
) -> Remote(List(TaskDependency)) {
  case deps {
    Loaded(items) -> Loaded([dep, ..items])
    _ -> Loaded([dep])
  }
}

pub fn remove_from_remote(
  deps: Remote(List(TaskDependency)),
  depends_on_task_id: Int,
) -> #(Remote(List(TaskDependency)), Int) {
  case deps {
    Loaded(items) -> {
      let #(remaining, removed_status) =
        list.fold(items, #([], opt.None), fn(acc, dep) {
          let #(kept, status_opt) = acc
          case dep.depends_on_task_id == depends_on_task_id {
            True -> #(kept, opt.Some(dep.status))
            False -> #([dep, ..kept], status_opt)
          }
        })
      let delta = case removed_status {
        opt.Some(Completed) | opt.None -> 0
        opt.Some(_) -> 1
      }
      #(Loaded(list.reverse(remaining)), delta)
    }
    _ -> #(deps, 0)
  }
}

pub fn add_to_task(task: Task, dep: TaskDependency) -> Task {
  Task(
    ..task,
    dependencies: [dep, ..task.dependencies],
    blocked_count: task.blocked_count + blocked_delta(dep),
  )
}

pub fn remove_from_task(task: Task, depends_on_task_id: Int, delta: Int) -> Task {
  Task(
    ..task,
    dependencies: list.filter(task.dependencies, fn(dep) {
      dep.depends_on_task_id != depends_on_task_id
    }),
    blocked_count: decrement_blocked_count(task.blocked_count, delta),
  )
}

pub fn blocked_delta(dep: TaskDependency) -> Int {
  case dep.status {
    Completed -> 0
    _ -> 1
  }
}

fn decrement_blocked_count(blocked_count: Int, delta: Int) -> Int {
  case blocked_count - delta {
    n if n < 0 -> 0
    n -> n
  }
}
