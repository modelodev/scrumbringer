//// Helpers for dictionary/list transformations.

import gleam/dict.{type Dict}
import gleam/list

import domain/task.{type Task, type TaskPosition, TaskPosition}
import domain/task_type.{type TaskType}

/// Convert a list of IDs to a boolean dictionary (all True).
pub fn ids_to_bool_dict(ids: List(Int)) -> Dict(Int, Bool) {
  ids |> list.fold(dict.new(), fn(acc, id) { dict.insert(acc, id, True) })
}

/// Extract IDs where value is True from a boolean dictionary.
pub fn bool_dict_to_ids(values: Dict(Int, Bool)) -> List(Int) {
  values
  |> dict.to_list
  |> list.filter_map(fn(pair) {
    let #(id, selected) = pair
    case selected {
      True -> Ok(id)
      False -> Error(Nil)
    }
  })
}

/// Convert a list of TaskPositions to a dictionary keyed by task_id.
pub fn positions_to_dict(
  positions: List(TaskPosition),
) -> Dict(Int, #(Int, Int)) {
  positions
  |> list.fold(dict.new(), fn(acc, pos) {
    let TaskPosition(task_id: task_id, x: x, y: y, ..) = pos
    dict.insert(acc, task_id, #(x, y))
  })
}

/// Flatten a Dict of project_id -> tasks into a single task list.
pub fn flatten_tasks(tasks_by_project: Dict(Int, List(Task))) -> List(Task) {
  tasks_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, tasks) = pair
    list.append(acc, tasks)
  })
}

/// Flatten a Dict of project_id -> task_types into a single list.
pub fn flatten_task_types(
  task_types_by_project: Dict(Int, List(TaskType)),
) -> List(TaskType) {
  task_types_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, types) = pair
    list.append(acc, types)
  })
}
