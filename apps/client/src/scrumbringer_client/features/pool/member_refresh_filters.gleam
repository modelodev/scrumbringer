//// Task filters used when refreshing member workspace data.

import gleam/option as opt

import domain/view_mode
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/helpers/options as helpers_options

pub type TaskRefreshSurface {
  PeopleRefresh
  PoolRefresh
  CapabilitiesRefresh
  PlanStructureRefresh
  PlanKanbanRefresh
}

pub fn surface(
  mode: view_mode.ViewMode,
  plan_mode: member_pool.PlanMode,
) -> TaskRefreshSurface {
  case mode {
    view_mode.People -> PeopleRefresh
    view_mode.Pool -> PoolRefresh
    view_mode.Capabilities -> CapabilitiesRefresh
    view_mode.Cards ->
      case plan_mode {
        member_pool.PlanStructure -> PlanStructureRefresh
        member_pool.PlanKanban -> PlanKanbanRefresh
      }
  }
}

pub fn task_filters(
  surface: TaskRefreshSurface,
  type_id: opt.Option(Int),
  capability_id: opt.Option(Int),
  search: String,
) -> task_operations_api.TaskFilters {
  case surface {
    PeopleRefresh | PlanStructureRefresh -> unfiltered()
    PoolRefresh | CapabilitiesRefresh | PlanKanbanRefresh ->
      task_operations_api.TaskFilters(
        status: opt.None,
        type_id: type_id,
        capability_id: capability_id,
        q: helpers_options.search_to_opt(search),
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
