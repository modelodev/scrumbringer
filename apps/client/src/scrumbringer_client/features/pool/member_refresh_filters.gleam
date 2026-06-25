//// Task filters used when refreshing member workspace data.

import gleam/option as opt

import domain/view_mode
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/helpers/options as helpers_options

pub fn task_filters(
  mode: view_mode.ViewMode,
  type_id: opt.Option(Int),
  capability_id: opt.Option(Int),
  search: String,
) -> task_operations_api.TaskFilters {
  case mode {
    view_mode.People -> unfiltered()
    view_mode.Pool | view_mode.Cards | view_mode.Capabilities ->
      task_operations_api.TaskFilters(
        status: opt.None,
        type_id: type_id,
        capability_id: capability_id,
        q: helpers_options.empty_to_opt(search),
        blocked: opt.None,
      )
  }
}

fn unfiltered() -> task_operations_api.TaskFilters {
  task_operations_api.TaskFilters(
    status: opt.None,
    type_id: opt.None,
    capability_id: opt.None,
    q: opt.None,
    blocked: opt.None,
  )
}
