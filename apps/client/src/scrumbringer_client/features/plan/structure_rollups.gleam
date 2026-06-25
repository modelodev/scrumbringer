//// Rollups for the Plan structure view.

import domain/card.{type Card, Active, Closed, Draft}
import domain/task as domain_task
import domain/task/state as task_execution_state
import gleam/list

import scrumbringer_client/features/plan/types
import scrumbringer_client/utils/card_queries

pub fn summary_for_rows(
  rows: List(types.StructureRow),
  cards: List(Card),
  tasks: List(domain_task.Task),
) -> types.CardRollup {
  let row_cards =
    rows
    |> list.map(fn(row) {
      let types.CardRow(card:, ..) = row
      card
    })

  let scoped_tasks =
    tasks
    |> list.filter(fn(task) {
      list.any(row_cards, fn(card) {
        card_queries.task_in_card_subtree(task, card.id, cards)
      })
    })

  let rollup = for_tasks(scoped_tasks)
  types.CardRollup(
    ..rollup,
    pool_impact: list.count(scoped_tasks, fn(task) {
      is_available_task(task)
      && list.any(row_cards, fn(card) {
        card.state == Draft
        && card_queries.task_in_card_subtree(task, card.id, cards)
      })
    }),
  )
}

pub fn for_tasks(tasks: List(domain_task.Task)) -> types.CardRollup {
  types.CardRollup(
    total_tasks: list.length(tasks),
    closed_tasks: list.count(tasks, is_closed_task),
    available_tasks: list.count(tasks, is_available_task),
    claimed_tasks: list.count(tasks, is_taken_task),
    ongoing_tasks: list.count(tasks, is_ongoing_task),
    blocked_tasks: list.count(tasks, fn(task) { task.blocked_count > 0 }),
    pool_impact: 0,
  )
}

pub fn for_card(
  card: Card,
  cards: List(Card),
  tasks: List(domain_task.Task),
) -> types.CardRollup {
  let card_tasks =
    tasks
    |> list.filter(fn(task) {
      card_queries.task_in_card_subtree(task, card.id, cards)
    })

  let rollup = for_tasks(card_tasks)
  types.CardRollup(..rollup, pool_impact: pool_impact(card, card_tasks))
}

pub fn pool_impact(card: Card, tasks: List(domain_task.Task)) -> Int {
  case card.state {
    Draft -> list.count(tasks, is_available_task)
    Active | Closed -> 0
  }
}

pub fn is_available_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Available -> True
    _ -> False
  }
}

pub fn is_taken_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Claimed(mode: task_execution_state.Taken, ..) -> True
    _ -> False
  }
}

pub fn is_ongoing_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Claimed(mode: task_execution_state.Ongoing, ..) -> True
    _ -> False
  }
}

pub fn is_closed_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Closed(..) -> True
    _ -> False
  }
}
