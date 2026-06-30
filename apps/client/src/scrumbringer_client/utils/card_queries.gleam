//// Card query helpers for Scrumbringer client.
////
//// ## Mission
////
//// Provides shared helper functions to query cards from loaded card sources.
//// These helpers are used across multiple features (admin, member, pool).
////
//// ## Responsibilities
////
//// - Find card by ID
//// - Get cards for current project
////
//// ## Non-responsibilities
////
//// - Card CRUD operations (see api/cards.gleam)
//// - Card state management (see features/admin/cards.gleam)

import gleam/int
import gleam/list
import gleam/option
import gleam/string

import domain/card.{type Card, type CardColor}
import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, Task}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/state/normalized_store.{type NormalizedStore}

/// Find a card by ID in the loaded cards list.
pub fn find_card(
  member_cards_store: NormalizedStore(Int, Card),
  admin_cards: Remote(List(Card)),
  card_id: Int,
) -> option.Option(Card) {
  case normalized_store.get_by_id(member_cards_store, card_id) {
    option.Some(card) -> option.Some(card)
    option.None ->
      case admin_cards {
        Loaded(cards) ->
          list.find(cards, fn(card) { card.id == card_id })
          |> option.from_result
        _ -> option.None
      }
  }
}

/// Get all cards for the currently selected project.
pub fn get_project_cards(
  member_cards_store: NormalizedStore(Int, Card),
  admin_cards: Remote(List(Card)),
  selected_project_id: option.Option(Int),
) -> List(Card) {
  case selected_project_id {
    option.Some(project_id) -> {
      let store_cards =
        normalized_store.get_by_project(member_cards_store, project_id)

      case list.is_empty(store_cards) {
        True ->
          case admin_cards {
            Loaded(cards) ->
              list.filter(cards, fn(card) { card.project_id == project_id })
            _ -> []
          }
        False -> store_cards
      }
    }
    option.None -> []
  }
}

/// Resolve card title and color for a task using a provided cards list.
pub fn resolve_task_card_info(
  cards: List(Card),
  task: Task,
) -> #(option.Option(String), option.Option(CardColor)) {
  let Task(card_id: card_id, card_title: card_title, card_color: card_color, ..) =
    task

  let loaded_card = case card_id {
    option.Some(cid) -> list.find(cards, fn(card) { card.id == cid })
    option.None -> Error(Nil)
  }

  let resolved_title = case card_title, loaded_card {
    option.Some(title), _ -> option.Some(title)
    option.None, Ok(card) -> option.Some(card.title)
    option.None, Error(_) -> option.None
  }

  let resolved_color = case card_color, loaded_card {
    option.Some(color), _ -> option.Some(color)
    option.None, Ok(card) -> card.color
    option.None, Error(_) -> option.None
  }

  #(resolved_title, resolved_color)
}

/// Return direct child cards for a parent card.
pub fn direct_child_cards(card_id: Int, cards: List(Card)) -> List(Card) {
  cards
  |> list.filter(fn(card) { card.parent_card_id == option.Some(card_id) })
  |> list.sort(fn(a, b) { string.compare(a.title, b.title) })
}

/// Return direct tasks for a card.
pub fn direct_child_tasks(card_id: Int, tasks: List(Task)) -> List(Task) {
  tasks
  |> list.filter(fn(task) { task.card_id == option.Some(card_id) })
  |> list.sort(fn(a, b) { string.compare(a.title, b.title) })
}

/// Return root cards, falling back to all cards for partially loaded trees.
pub fn top_level_cards(cards: List(Card)) -> List(Card) {
  case list.filter(cards, fn(card) { card.parent_card_id == option.None }) {
    [] -> cards
    roots -> roots |> list.sort(fn(a, b) { string.compare(a.title, b.title) })
  }
}

/// Determine a card depth from the loaded hierarchy. Root cards are depth 1.
pub fn card_depth(card: Card, cards: List(Card)) -> Int {
  case card.parent_card_id {
    option.None -> 1
    option.Some(parent_id) ->
      case list.find(cards, fn(candidate) { candidate.id == parent_id }) {
        Ok(parent) -> 1 + card_depth(parent, cards)
        Error(_) -> 1
      }
  }
}

/// Return the configured singular label for a depth.
pub fn depth_singular_label(
  depth_names: List(scope_view.DepthName),
  depth: Int,
) -> String {
  case list.find(depth_names, fn(name) { name.depth == depth }) {
    Ok(scope_view.DepthName(singular_name: name, ..)) -> name
    Error(_) -> "Level " <> int_to_string(depth)
  }
}

/// Returns true when `candidate_id` is the ancestor card or below it.
pub fn card_in_subtree(
  candidate_id: Int,
  ancestor_id: Int,
  all_cards: List(Card),
) -> Bool {
  case candidate_id == ancestor_id {
    True -> True
    False ->
      case list.find(all_cards, fn(card) { card.id == candidate_id }) {
        Ok(card) ->
          case card.parent_card_id {
            option.Some(parent_id) ->
              card_in_subtree(parent_id, ancestor_id, all_cards)
            option.None -> False
          }
        Error(_) -> False
      }
  }
}

/// Returns true when the task belongs to a card subtree.
pub fn task_in_card_subtree(
  task: Task,
  ancestor_id: Int,
  all_cards: List(Card),
) -> Bool {
  case task.card_id {
    option.Some(card_id) -> card_in_subtree(card_id, ancestor_id, all_cards)
    option.None -> False
  }
}

/// Cards visible for the shared Plan scope controls.
pub fn cards_for_scope(
  cards: List(Card),
  scope_kind: member_pool.PlanScopeKind,
  selected_depth: option.Option(Int),
  selected_card_id: option.Option(Int),
) -> List(Card) {
  case scope_kind {
    member_pool.PlanScopeProject -> cards
    member_pool.PlanScopeLevel ->
      case selected_depth {
        option.None -> cards
        option.Some(depth) ->
          list.filter(cards, fn(card) { card_depth(card, cards) == depth })
      }
    member_pool.PlanScopeCard ->
      case selected_card_id {
        option.None -> cards
        option.Some(card_id) ->
          list.filter(cards, fn(card) {
            card_in_subtree(card.id, card_id, cards)
          })
      }
  }
}

/// Row cards for scoped matrix/list surfaces.
pub fn row_cards_for_scope(
  cards: List(Card),
  scope_kind: member_pool.PlanScopeKind,
  selected_depth: option.Option(Int),
  selected_card_id: option.Option(Int),
) -> List(Card) {
  case scope_kind {
    member_pool.PlanScopeProject -> top_level_cards(cards)
    member_pool.PlanScopeLevel ->
      case selected_depth {
        option.None -> top_level_cards(cards)
        option.Some(depth) ->
          list.filter(cards, fn(card) { card_depth(card, cards) == depth })
      }
    member_pool.PlanScopeCard ->
      case selected_card_id {
        option.None -> top_level_cards(cards)
        option.Some(card_id) ->
          case direct_child_cards(card_id, cards) {
            [] -> list.filter(cards, fn(card) { card.id == card_id })
            children -> children
          }
      }
  }
}

/// Default closed-history behavior for a scope.
pub fn closed_default_for_scope(
  cards: List(Card),
  tasks: List(Task),
  scope_kind: member_pool.PlanScopeKind,
  selected_card_id: option.Option(Int),
) -> Bool {
  case scope_kind, selected_card_id {
    member_pool.PlanScopeCard, option.Some(card_id) -> {
      let has_child_cards =
        list.any(cards, fn(card) { card.parent_card_id == option.Some(card_id) })
      let has_direct_tasks =
        list.any(tasks, fn(task) { task.card_id == option.Some(card_id) })

      has_direct_tasks && !has_child_cards
    }
    _, _ -> False
  }
}

/// Build a slash-separated card path.
pub fn card_path(card: Card, cards: List(Card)) -> String {
  card_path_parts(card, cards)
  |> list.reverse
  |> string.join(" / ")
}

pub fn parent_path(card: Card, cards: List(Card)) -> String {
  case card.parent_card_id {
    option.None -> ""
    option.Some(parent_id) ->
      case list.find(cards, fn(candidate) { candidate.id == parent_id }) {
        Ok(parent) -> card_path(parent, cards)
        Error(_) -> ""
      }
  }
}

fn card_path_parts(card: Card, cards: List(Card)) -> List(String) {
  case card.parent_card_id {
    option.None -> [card.title]
    option.Some(parent_id) ->
      case list.find(cards, fn(candidate) { candidate.id == parent_id }) {
        Ok(parent) -> [card.title, ..card_path_parts(parent, cards)]
        Error(_) -> [card.title]
      }
  }
}

fn int_to_string(value: Int) -> String {
  value |> int.to_string
}
