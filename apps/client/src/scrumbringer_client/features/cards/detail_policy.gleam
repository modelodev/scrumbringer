//// Card detail action policy for hierarchy-aware card operations.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/card.{type Card, Closed}
import domain/task.{type Task, claimed_by}

pub type DetailStructure {
  EmptyCard
  CardGroup
  TaskGroup
}

pub type Policy {
  Policy(
    structure: DetailStructure,
    can_create_card: Bool,
    can_create_task: Bool,
    can_delete: Bool,
    create_disabled_reason: Option(String),
    delete_disabled_reason: Option(String),
  )
}

pub fn policy_for(
  card: Card,
  direct_child_cards: List(Card),
  direct_tasks: List(Task),
  can_manage_structure: Bool,
  can_execute_work: Bool,
) -> Policy {
  let structure = structure_for(card, direct_child_cards, direct_tasks)
  let is_closed = card.state == Closed
  let create_disabled_reason = case is_closed {
    True -> Some("Closed cards cannot receive new children")
    False -> None
  }
  let can_create_card =
    !is_closed
    && can_manage_structure
    && case structure {
      EmptyCard | CardGroup -> True
      TaskGroup -> False
    }
  let can_create_task =
    !is_closed
    && can_execute_work
    && case structure {
      EmptyCard | TaskGroup -> True
      CardGroup -> False
    }
  let can_delete =
    !has_operational_history(card, direct_child_cards, direct_tasks)
  let delete_disabled_reason = case can_delete {
    True -> None
    False -> Some("Cannot delete: has operational history")
  }

  Policy(
    structure: structure,
    can_create_card: can_create_card,
    can_create_task: can_create_task,
    can_delete: can_delete,
    create_disabled_reason: create_disabled_reason,
    delete_disabled_reason: delete_disabled_reason,
  )
}

pub fn structure_for(
  card: Card,
  direct_child_cards: List(Card),
  direct_tasks: List(Task),
) -> DetailStructure {
  case
    list.is_empty(direct_child_cards),
    list.is_empty(direct_tasks),
    card.task_count
  {
    False, _, _ -> CardGroup
    True, False, _ -> TaskGroup
    True, True, count if count > 0 -> TaskGroup
    True, True, _ -> EmptyCard
  }
}

pub fn direct_child_cards(card: Card, cards: List(Card)) -> List(Card) {
  list.filter(cards, fn(candidate) { candidate.parent_card_id == Some(card.id) })
}

pub fn move_destinations(card: Card, cards: List(Card)) -> List(Card) {
  let current_depth = card_depth(card, cards)
  cards
  |> list.filter(fn(candidate) {
    candidate.id != card.id
    && candidate.id != option_to_disallowed_parent_id(card.parent_card_id)
    && candidate.project_id == card.project_id
    && candidate.state != Closed
    && card_depth(candidate, cards) == current_depth - 1
    && accepts_child_cards(candidate, cards)
    && !is_descendant(candidate, card, cards)
  })
}

fn option_to_disallowed_parent_id(parent_id: Option(Int)) -> Int {
  case parent_id {
    Some(id) -> id
    None -> -1
  }
}

pub fn invalid_move_explanation(
  card: Card,
  destination: Card,
  cards: List(Card),
) -> String {
  let same_level_text = case
    card_depth(destination, cards) == card_depth(card, cards) - 1
  {
    True -> "Destination keeps the card at the same level."
    False -> "Destination must keep the card at the same level."
  }
  let accepts_text = case accepts_child_cards(destination, cards) {
    True -> "Destination accepts child cards."
    False -> "Destination does not accept child cards."
  }
  same_level_text <> " " <> accepts_text
}

pub fn task_is_auto_claimed(task: Task, creator_id: Int) -> Bool {
  case claimed_by(task) {
    Some(user_id) -> user_id == creator_id
    None -> False
  }
}

pub fn card_depth(card: Card, cards: List(Card)) -> Int {
  do_card_depth(card, cards, [])
}

fn do_card_depth(card: Card, cards: List(Card), seen: List(Int)) -> Int {
  case card.parent_card_id {
    None -> 1
    Some(parent_id) ->
      case list.contains(seen, parent_id) {
        True -> 1
        False ->
          case list.find(cards, fn(candidate) { candidate.id == parent_id }) {
            Ok(parent) -> 1 + do_card_depth(parent, cards, [card.id, ..seen])
            Error(_) -> 1
          }
      }
  }
}

fn has_operational_history(
  card: Card,
  direct_child_cards: List(Card),
  direct_tasks: List(Task),
) -> Bool {
  card.task_count > 0
  || card.completed_count > 0
  || card.has_new_notes
  || !list.is_empty(direct_child_cards)
  || !list.is_empty(direct_tasks)
}

fn accepts_child_cards(card: Card, cards: List(Card)) -> Bool {
  case structure_for(card, direct_child_cards(card, cards), []) {
    EmptyCard | CardGroup -> True
    TaskGroup -> False
  }
}

fn is_descendant(candidate: Card, ancestor: Card, cards: List(Card)) -> Bool {
  case candidate.parent_card_id {
    None -> False
    Some(parent_id) if parent_id == ancestor.id -> True
    Some(parent_id) ->
      case list.find(cards, fn(card) { card.id == parent_id }) {
        Ok(parent) -> is_descendant(parent, ancestor, cards)
        Error(_) -> False
      }
  }
}
