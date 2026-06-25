//// Filtering and ordering helpers for the Plan structure view.

import domain/card.{type Card, Active, Closed, Draft}
import domain/due_date as due_date_domain
import domain/task as domain_task
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/plan/structure_rollups
import scrumbringer_client/utils/card_queries

pub fn include_closed(
  show_closed: Option(Bool),
  cards: List(Card),
  tasks: List(domain_task.Task),
  scope_kind: member_pool.PlanScopeKind,
  selected_card_id: Option(Int),
) -> Bool {
  case show_closed {
    Some(value) -> value
    None ->
      card_queries.closed_default_for_scope(
        cards,
        tasks,
        scope_kind,
        selected_card_id,
      )
  }
}

pub fn visible_cards(cards: List(Card), include_closed: Bool) -> List(Card) {
  case include_closed {
    True -> cards
    False -> list.filter(cards, fn(card) { card.state != Closed })
  }
}

pub fn matches_search(
  search_query: String,
  cards: List(Card),
  card: Card,
) -> Bool {
  let query = string.lowercase(string.trim(search_query))
  case query {
    "" -> True
    _ -> {
      let haystack =
        string.lowercase(
          card.title <> " " <> card_queries.card_path(card, cards),
        )
      string.contains(haystack, query)
    }
  }
}

pub fn matches_status(
  status_filter: member_pool.PlanStatusFilter,
  card: Card,
) -> Bool {
  case status_filter, card.state {
    member_pool.PlanStatusAll, _ -> True
    member_pool.PlanStatusDraft, Draft -> True
    member_pool.PlanStatusActive, Active -> True
    member_pool.PlanStatusClosed, Closed -> True
    _, _ -> False
  }
}

pub fn compare_cards(
  sort_order: member_pool.PlanSort,
  cards: List(Card),
  tasks: List(domain_task.Task),
  a: Card,
  b: Card,
) -> order.Order {
  case sort_order {
    member_pool.PlanSortPath ->
      string.compare(
        card_queries.card_path(a, cards),
        card_queries.card_path(b, cards),
      )
    member_pool.PlanSortState ->
      case int.compare(card_state_rank(a), card_state_rank(b)) {
        order.Eq -> string.compare(a.title, b.title)
        other -> other
      }
    member_pool.PlanSortDueDate ->
      case string.compare(due_date_sort_value(a), due_date_sort_value(b)) {
        order.Eq -> string.compare(a.title, b.title)
        other -> other
      }
    member_pool.PlanSortPoolImpact ->
      case
        int.compare(
          structure_rollups.for_card(b, cards, tasks).pool_impact,
          structure_rollups.for_card(a, cards, tasks).pool_impact,
        )
      {
        order.Eq -> string.compare(a.title, b.title)
        other -> other
      }
  }
}

pub fn is_collapsed(collapsed_card_ids: List(Int), card_id: Int) -> Bool {
  list.contains(collapsed_card_ids, card_id)
}

pub fn card_state_rank(card: Card) -> Int {
  case card.state {
    Active -> 0
    Draft -> 1
    Closed -> 2
  }
}

fn due_date_sort_value(card: Card) -> String {
  case card.due_date {
    Some(value) ->
      case due_date_domain.parse(value) {
        Ok(parsed) -> due_date_domain.to_string(parsed)
        Error(_) -> no_due_date_sort_value
      }
    None -> no_due_date_sort_value
  }
}

const no_due_date_sort_value = "9999-12-31"

pub fn plan_status_value(status: member_pool.PlanStatusFilter) -> String {
  case status {
    member_pool.PlanStatusAll -> "all"
    member_pool.PlanStatusDraft -> "draft"
    member_pool.PlanStatusActive -> "active"
    member_pool.PlanStatusClosed -> "closed"
  }
}

pub fn plan_sort_value(sort: member_pool.PlanSort) -> String {
  case sort {
    member_pool.PlanSortPath -> "path"
    member_pool.PlanSortState -> "state"
    member_pool.PlanSortDueDate -> "due_date"
    member_pool.PlanSortPoolImpact -> "pool_impact"
  }
}
