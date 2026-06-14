//// Helpers for remote/cache lookups.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}

import domain/org.{type OrgUser}
import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, Task}

/// Find a task by ID in a Remote list of tasks.
pub fn find_task_by_id(tasks: Remote(List(Task)), task_id: Int) -> Option(Task) {
  case tasks {
    Loaded(tasks) ->
      case
        list.find(tasks, fn(t) {
          let Task(id: id, ..) = t
          id == task_id
        })
      {
        Ok(t) -> Some(t)
        Error(_) -> None
      }

    _ -> None
  }
}

/// Find a task by ID in the active Remote list, falling back to per-project
/// task caches populated by project refreshes.
pub fn find_task_by_id_in_cache(
  tasks: Remote(List(Task)),
  tasks_by_project: Dict(Int, List(Task)),
  task_id: Int,
) -> Option(Task) {
  case find_task_by_id(tasks, task_id) {
    Some(task) -> Some(task)
    None ->
      tasks_by_project
      |> dict.values
      |> list.flatten
      |> find_task_in_list(task_id)
  }
}

fn find_task_in_list(tasks: List(Task), task_id: Int) -> Option(Task) {
  case
    list.find(tasks, fn(t) {
      let Task(id: id, ..) = t
      id == task_id
    })
  {
    Ok(t) -> Some(t)
    Error(_) -> None
  }
}

/// Resolve an org user from a Remote cache by user ID.
pub fn resolve_org_user(
  cache: Remote(List(OrgUser)),
  user_id: Int,
) -> Option(OrgUser) {
  case cache {
    Loaded(users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(user) -> Some(user)
        Error(_) -> None
      }

    _ -> None
  }
}
