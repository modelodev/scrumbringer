//// Rollups for the Plan structure view.

import domain/card.{type Card, Active, Closed, Draft}
import domain/task as domain_task
import gleam/list

import scrumbringer_client/features/plan/types
import scrumbringer_client/features/tasks/rollup as task_rollup
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
      task_rollup.is_available(task)
      && list.any(row_cards, fn(card) {
        card.state == Draft
        && card_queries.task_in_card_subtree(task, card.id, cards)
      })
    }),
  )
}

fn for_tasks(tasks: List(domain_task.Task)) -> types.CardRollup {
  let rollup = task_rollup.from_tasks(tasks)

  types.CardRollup(
    total_tasks: rollup.total,
    closed_tasks: rollup.closed,
    available_tasks: rollup.available,
    claimed_tasks: rollup.claimed,
    ongoing_tasks: rollup.ongoing,
    blocked_tasks: rollup.blocked,
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
    Draft -> list.count(tasks, task_rollup.is_available)
    Active | Closed -> 0
  }
}
