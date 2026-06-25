//// Pure task-list transformations over remote member tasks.

import gleam/list
import gleam/option as opt

import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, with_state}
import domain/task/state.{type TaskExecutionState}

pub fn snapshot(tasks: Remote(List(Task))) -> opt.Option(List(Task)) {
  case tasks {
    Loaded(items) -> opt.Some(items)
    _ -> opt.None
  }
}

pub fn update(
  tasks: Remote(List(Task)),
  task_id: Int,
  change: fn(Task) -> Task,
) -> Remote(List(Task)) {
  case tasks {
    Loaded(items) ->
      Loaded(
        items
        |> list.map(fn(task) {
          case task.id == task_id {
            True -> change(task)
            False -> task
          }
        }),
      )
    _ -> tasks
  }
}

pub fn replace(
  tasks: Remote(List(Task)),
  updated_task: Task,
) -> Remote(List(Task)) {
  update(tasks, updated_task.id, fn(_task) { updated_task })
}

pub fn remove(tasks: Remote(List(Task)), task_id: Int) -> Remote(List(Task)) {
  case tasks {
    Loaded(items) -> Loaded(list.filter(items, fn(task) { task.id != task_id }))
    _ -> tasks
  }
}

pub fn set_state(
  tasks: Remote(List(Task)),
  task_id: Int,
  state: TaskExecutionState,
) -> Remote(List(Task)) {
  update(tasks, task_id, fn(task) { with_state(task, state) })
}
