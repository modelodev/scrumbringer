import gleam/list
import gleam/option.{type Option}

import domain/remote as rem
import domain/task as domain_task
import domain/task/state as task_state
import domain/task_type.{type TaskType}
import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/features/pool/visibility.{type PoolVisibility}
import scrumbringer_client/features/work_filters

pub type Config {
  Config(
    tasks: rem.Remote(List(domain_task.Task)),
    task_types: rem.Remote(List(TaskType)),
    my_capability_ids: rem.Remote(List(Int)),
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search_query: String,
    capability_scope: CapabilityScope,
    visibility: PoolVisibility,
  )
}

pub type State {
  Loading
  Error(message: String)
  Empty(has_filters: Bool)
  Ready(tasks: List(domain_task.Task))
}

pub type Counts {
  Counts(open: Int, ready: Int, blocked: Int)
}

pub fn state(config: Config) -> State {
  case config.tasks {
    rem.NotAsked | rem.Loading -> Loading
    rem.Failed(err) -> Error(err.message)
    rem.Loaded(tasks) -> {
      let filters = filters(config)
      let available =
        tasks
        |> list.filter(fn(task) {
          is_open_pool_task(task)
          && visibility.matches(config.visibility, task.blocked_count)
          && matches(filters, task)
        })

      case available {
        [] -> Empty(has_filters: has_active_filters(config, filters))
        _ -> Ready(available)
      }
    }
  }
}

pub fn is_open_pool_task(task: domain_task.Task) -> Bool {
  task.state == task_state.Available
}

pub fn matches_visibility(
  selected_visibility: PoolVisibility,
  task: domain_task.Task,
) -> Bool {
  is_open_pool_task(task)
  && visibility.matches(selected_visibility, task.blocked_count)
}

pub fn matches_work_filters(config: Config, task: domain_task.Task) -> Bool {
  matches(filters(config), task)
}

pub fn counts(config: Config) -> Counts {
  case config.tasks {
    rem.Loaded(tasks) -> {
      let filters = filters(config)
      let open_tasks =
        list.filter(tasks, fn(task) {
          is_open_pool_task(task) && matches(filters, task)
        })
      let blocked_count =
        open_tasks
        |> list.filter(fn(task) { task.blocked_count > 0 })
        |> list.length
      let open_count = list.length(open_tasks)

      Counts(
        open: open_count,
        ready: open_count - blocked_count,
        blocked: blocked_count,
      )
    }
    _ -> Counts(open: 0, ready: 0, blocked: 0)
  }
}

fn has_active_filters(config: Config, filters: work_filters.Filters) -> Bool {
  work_filters.has_active_filters(filters)
  || config.visibility != visibility.default()
}

fn matches(filters: work_filters.Filters, task: domain_task.Task) -> Bool {
  work_filters.matches(filters, task)
}

fn filters(config: Config) -> work_filters.Filters {
  work_filters.Filters(
    type_filter: config.type_filter,
    capability_filter: config.capability_filter,
    search_query: config.search_query,
    capability_scope: config.capability_scope,
    my_capability_ids: loaded_or_empty(config.my_capability_ids),
    task_types: loaded_or_empty(config.task_types),
  )
}

fn loaded_or_empty(remote: rem.Remote(List(a))) -> List(a) {
  case remote {
    rem.Loaded(items) -> items
    _ -> []
  }
}
