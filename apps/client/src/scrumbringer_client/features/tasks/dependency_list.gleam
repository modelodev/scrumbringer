//// Pure task dependency transformations for local Task Show state.

import gleam/list
import gleam/option as opt

import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, type TaskDependency, Task, dependency_is_closed}

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
      let #(remaining, removed_closed) =
        list.fold(items, #([], opt.None), fn(acc, dep) {
          let #(kept, closed_opt) = acc
          case dep.depends_on_task_id == depends_on_task_id {
            True -> #(kept, opt.Some(dependency_is_closed(dep)))
            False -> #([dep, ..kept], closed_opt)
          }
        })
      let delta = case removed_closed {
        opt.Some(True) | opt.None -> 0
        opt.Some(False) -> 1
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
  case dependency_is_closed(dep) {
    True -> 0
    False -> 1
  }
}

fn decrement_blocked_count(blocked_count: Int, delta: Int) -> Int {
  case blocked_count - delta {
    n if n < 0 -> 0
    n -> n
  }
}
