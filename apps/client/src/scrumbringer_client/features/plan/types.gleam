//// Typed model for the member Plan surface.

import domain/card.{type Card}
import domain/task.{type Task}

pub type CardRollup {
  CardRollup(
    total_tasks: Int,
    completed_tasks: Int,
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
  EmptyCardDetail(card: Card, rollup: CardRollup)
}
