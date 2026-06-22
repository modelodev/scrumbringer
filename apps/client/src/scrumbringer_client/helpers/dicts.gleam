//// Helpers for dictionary/list transformations.

import gleam/dict.{type Dict}
import gleam/int
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

/// Compact positions for the currently displayed task IDs.
///
/// Positions outside `task_ids` are preserved untouched so hidden tasks do not
/// influence the visible canvas origin.
pub fn compact_positions_for_task_ids(
  positions: Dict(Int, #(Int, Int)),
  task_ids: List(Int),
  padding: Int,
) -> Dict(Int, #(Int, Int)) {
  let selected =
    task_ids
    |> list.filter_map(fn(task_id) {
      case dict.get(positions, task_id) {
        Ok(#(x, y)) -> Ok(#(task_id, x, y))
        Error(_) -> Error(Nil)
      }
    })

  case selected {
    [] -> positions
    [first, ..rest] -> {
      let #(_first_task_id, first_x, first_y) = first
      let #(min_x, min_y) =
        list.fold(rest, #(first_x, first_y), fn(minimums, item) {
          let #(current_min_x, current_min_y) = minimums
          let #(_task_id, x, y) = item
          #(int.min(current_min_x, x), int.min(current_min_y, y))
        })
      let anchor_y = leftmost_y(selected, min_x, min_y)
      let shift_x = int.max(0, min_x - padding)
      let shift_y = int.max(0, anchor_y - padding)

      selected
      |> list.fold(positions, fn(acc, item) {
        let #(task_id, x, y) = item
        dict.insert(acc, task_id, #(
          int.max(0, x - shift_x),
          int.max(0, y - shift_y),
        ))
      })
    }
  }
}

fn leftmost_y(
  positions: List(#(Int, Int, Int)),
  min_x: Int,
  fallback_y: Int,
) -> Int {
  let #(best_y, _) =
    positions
    |> list.fold(#(fallback_y, False), fn(best, item) {
      let #(best_y, found) = best
      let #(_task_id, x, y) = item
      case x == min_x {
        True ->
          case found {
            True -> #(int.min(best_y, y), True)
            False -> #(y, True)
          }
        False -> best
      }
    })

  best_y
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
