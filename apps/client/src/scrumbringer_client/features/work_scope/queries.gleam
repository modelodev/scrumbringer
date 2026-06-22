//// Shared work-scope queries for card-backed work views.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/card.{type Card}
import domain/task.{type Task}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/utils/card_queries

/// Return tasks that belong to the selected shared Plan scope.
pub fn tasks_in_scope(
  tasks: List(Task),
  cards: List(Card),
  scope_kind: member_pool.PlanScopeKind,
  selected_depth: Option(Int),
  selected_card_id: Option(Int),
) -> List(Task) {
  list.filter(tasks, fn(task) {
    task_in_scope(task, cards, scope_kind, selected_depth, selected_card_id)
  })
}

/// Determine whether a task belongs to the selected shared Plan scope.
pub fn task_in_scope(
  task: Task,
  cards: List(Card),
  scope_kind: member_pool.PlanScopeKind,
  selected_depth: Option(Int),
  selected_card_id: Option(Int),
) -> Bool {
  case scope_kind {
    member_pool.PlanScopeProject -> True
    member_pool.PlanScopeLevel ->
      task_in_level_scope(task, cards, selected_depth)
    member_pool.PlanScopeCard ->
      task_in_card_scope(task, cards, selected_card_id)
  }
}

fn task_in_level_scope(
  task: Task,
  cards: List(Card),
  selected_depth: Option(Int),
) -> Bool {
  case selected_depth {
    None -> True
    Some(depth) ->
      cards
      |> list.filter(fn(card) { card_queries.card_depth(card, cards) == depth })
      |> list.any(fn(card) {
        card_queries.task_in_card_subtree(task, card.id, cards)
      })
  }
}

fn task_in_card_scope(
  task: Task,
  cards: List(Card),
  selected_card_id: Option(Int),
) -> Bool {
  case selected_card_id {
    None -> False
    Some(card_id) -> card_queries.task_in_card_subtree(task, card_id, cards)
  }
}
