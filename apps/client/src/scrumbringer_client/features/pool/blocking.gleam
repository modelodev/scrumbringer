//// Pure blocked-dependency derivations for pool tasks.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, type TaskDependency, Task, dependency_is_closed}

pub fn open_dependencies(task: Task) -> List(TaskDependency) {
  let Task(dependencies: dependencies, ..) = task
  list.filter(dependencies, is_open)
}

pub fn open_dependencies_or_empty(task: Option(Task)) -> List(TaskDependency) {
  case task {
    Some(task) -> open_dependencies(task)
    None -> []
  }
}

pub fn open_dependency_ids(task: Task) -> List(Int) {
  task
  |> open_dependencies
  |> list.map(fn(dep) { dep.depends_on_task_id })
}

pub fn open_dependency_count(dependencies: List(TaskDependency)) -> Int {
  list.count(dependencies, is_open)
}

pub fn hidden_count(tasks: Remote(List(Task)), blocker_ids: List(Int)) -> Int {
  let hidden = list.length(blocker_ids) - visible_count(tasks, blocker_ids)
  case hidden {
    n if n < 0 -> 0
    n -> n
  }
}

fn is_open(dep: TaskDependency) -> Bool {
  !dependency_is_closed(dep)
}

fn visible_count(tasks: Remote(List(Task)), blocker_ids: List(Int)) -> Int {
  case tasks {
    Loaded(tasks) ->
      blocker_ids
      |> list.filter(fn(blocker_id) {
        list.any(tasks, fn(task) {
          let Task(id: task_id, ..) = task
          task_id == blocker_id
        })
      })
      |> list.length
    _ -> 0
  }
}
