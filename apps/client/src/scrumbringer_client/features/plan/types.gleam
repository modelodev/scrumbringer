//// Typed model for the member Plan surface.

import domain/card.{type Card}
import domain/task.{type Task}
import scrumbringer_client/client_state/member/pool as member_pool

pub type PlanFilters {
  PlanFilters(
    status: member_pool.PlanStatusFilter,
    sort: member_pool.PlanSort,
    search_query: String,
    include_closed: Bool,
  )
}

pub type CardRollup {
  CardRollup(
    total_tasks: Int,
    closed_tasks: Int,
    available_tasks: Int,
    claimed_tasks: Int,
    ongoing_tasks: Int,
    blocked_tasks: Int,
    pool_impact: Int,
  )
}

pub type CardAction {
  CreateSubcard
  CreateTask
  ActivateSubtree
  MoveCard
  CloseCard
  DeleteCard
}

pub type ActionAvailability {
  Available
  Disabled(reason: String)
}

pub type PlannedAction {
  PlannedAction(action: CardAction, availability: ActionAvailability)
}

pub type StructureRow {
  CardRow(
    depth: Int,
    card: Card,
    path: String,
    level_name: String,
    rollup: CardRollup,
    actions: List(PlannedAction),
  )
}

pub type StructureDetail {
  SubcardsDetail(card: Card, subcards: List(Card), rollup: CardRollup)
  TasksDetail(card: Card, tasks: List(Task), rollup: CardRollup)
  EmptyCardContent(card: Card, rollup: CardRollup)
}
