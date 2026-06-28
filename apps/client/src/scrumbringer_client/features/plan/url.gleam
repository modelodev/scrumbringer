//// URL conversions for Plan-specific state.

import gleam/string

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/url_state

pub fn mode_from_url(mode: url_state.PlanModeParam) -> member_pool.PlanMode {
  case mode {
    url_state.PlanStructureParam -> member_pool.PlanStructure
    url_state.PlanKanbanParam -> member_pool.PlanKanban
  }
}

pub fn mode_from_control_value(value: String) -> member_pool.PlanMode {
  case string.trim(value) {
    "kanban" -> member_pool.PlanKanban
    _ -> member_pool.PlanStructure
  }
}
