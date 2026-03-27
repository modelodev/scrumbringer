import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import domain/task.{type Task}
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/capability_scope.{
  type CapabilityScope, AllCapabilities, MyCapabilities,
}

pub type Filters {
  Filters(
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search_query: String,
    capability_scope: CapabilityScope,
    my_capability_ids: List(Int),
    task_types: List(TaskType),
  )
}

pub fn matches(filters: Filters, task: Task) -> Bool {
  let Filters(
    type_filter: type_filter,
    capability_filter: capability_filter,
    search_query: search_query,
    capability_scope: capability_scope,
    my_capability_ids: my_capability_ids,
    task_types: task_types,
  ) = filters

  let type_ok = case type_filter {
    Some(type_id) -> task.type_id == type_id
    None -> True
  }

  let capability_id = task_capability_id(task, task_types)
  let capability_ok = case capability_filter {
    Some(selected_id) -> capability_id == Some(selected_id)
    None -> True
  }

  let scope_ok = case capability_scope {
    AllCapabilities -> True
    MyCapabilities ->
      case capability_id {
        Some(id) -> list.contains(my_capability_ids, id)
        None -> False
      }
  }

  let query_ok = case string.trim(search_query) {
    "" -> True
    query -> {
      let lowered = string.lowercase(query)
      let in_title = string.contains(string.lowercase(task.title), lowered)
      let in_description = case task.description {
        Some(description) ->
          string.contains(string.lowercase(description), lowered)
        None -> False
      }
      in_title || in_description
    }
  }

  type_ok && capability_ok && scope_ok && query_ok
}

pub fn has_active_filters(filters: Filters) -> Bool {
  let Filters(
    type_filter: type_filter,
    capability_filter: capability_filter,
    search_query: search_query,
    capability_scope: capability_scope,
    ..,
  ) = filters

  type_filter != None
  || capability_filter != None
  || string.trim(search_query) != ""
  || capability_scope == MyCapabilities
}

pub fn task_capability_id(task: Task, task_types: List(TaskType)) -> Option(Int) {
  case list.find(task_types, fn(task_type) { task_type.id == task.type_id }) {
    Ok(TaskType(capability_id: capability_id, ..)) -> capability_id
    Error(_) -> None
  }
}
