//// Card policy for hierarchy-aware card operations.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/card.{type Card, Active, Closed}
import domain/task.{type Task, claimed_by}

pub type CardStructure {
  EmptyCard
  CardGroup
  TaskGroup
}

pub type DisabledReason {
  ClosedCardCannotReceiveChildren
  CardHasOperationalHistory
}

pub type MoveBlockedReason {
  SourceClosed
  AlreadyAtProjectRoot
  SameParent
  ClosedDestination
  DestinationContainsTasks
  SelfOrDescendant
  DestinationNotFound
  NoAvailableDestination
}

pub type MoveDestination {
  ValidDestination(card: Card)
  InvalidDestination(card: Card, reason: MoveBlockedReason)
}

pub type Policy {
  Policy(
    structure: CardStructure,
    can_create_card: Bool,
    can_create_task: Bool,
    can_delete: Bool,
    create_disabled_reason: Option(DisabledReason),
    delete_disabled_reason: Option(DisabledReason),
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
    True -> Some(ClosedCardCannotReceiveChildren)
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
    && card_accepts_direct_tasks(card, direct_child_cards)
    && can_execute_work
    && case structure {
      EmptyCard | TaskGroup -> True
      CardGroup -> False
    }
  let can_delete =
    !has_operational_history(card, direct_child_cards, direct_tasks)
  let delete_disabled_reason = case can_delete {
    True -> None
    False -> Some(CardHasOperationalHistory)
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

pub fn card_accepts_direct_tasks(
  card: Card,
  direct_child_cards: List(Card),
) -> Bool {
  card.state == Active && list.is_empty(direct_child_cards)
}

pub fn structure_for(
  card: Card,
  direct_child_cards: List(Card),
  direct_tasks: List(Task),
) -> CardStructure {
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
  move_destination_entries(card, cards, [])
  |> list.filter_map(fn(entry) {
    case entry {
      ValidDestination(card) -> Ok(card)
      InvalidDestination(_, _) -> Error(Nil)
    }
  })
}

pub fn move_destination_entries(
  card: Card,
  cards: List(Card),
  tasks: List(Task),
) -> List(MoveDestination) {
  cards
  |> list.filter(fn(candidate) { candidate.project_id == card.project_id })
  |> list.map(fn(candidate) {
    case move_blocked_reason(card, candidate, cards, tasks) {
      None -> ValidDestination(candidate)
      Some(reason) -> InvalidDestination(candidate, reason)
    }
  })
}

pub fn move_unavailable_reason(
  card: Card,
  cards: List(Card),
  tasks: List(Task),
) -> Option(MoveBlockedReason) {
  case card.state {
    Closed -> Some(SourceClosed)
    _ ->
      case
        card.parent_card_id,
        move_destinations_with_tasks(card, cards, tasks)
      {
        None, [] -> Some(NoAvailableDestination)
        _, _ -> None
      }
  }
}

pub fn move_to_root_blocked_reason(card: Card) -> Option(MoveBlockedReason) {
  case card.state, card.parent_card_id {
    Closed, _ -> Some(SourceClosed)
    _, None -> Some(AlreadyAtProjectRoot)
    _, Some(_) -> None
  }
}

fn move_destinations_with_tasks(
  card: Card,
  cards: List(Card),
  tasks: List(Task),
) -> List(Card) {
  move_destination_entries(card, cards, tasks)
  |> list.filter_map(fn(entry) {
    case entry {
      ValidDestination(card) -> Ok(card)
      InvalidDestination(_, _) -> Error(Nil)
    }
  })
}

pub fn move_blocked_reason(
  card: Card,
  destination: Card,
  cards: List(Card),
  tasks: List(Task),
) -> Option(MoveBlockedReason) {
  let destination_is_descendant = is_descendant(destination, card, cards)
  let accepts_children = accepts_child_cards(destination, cards, tasks)

  case card.state, card.parent_card_id, destination.id == card.id {
    Closed, _, _ -> Some(SourceClosed)
    _, _, True -> Some(SelfOrDescendant)
    _, Some(parent_id), _ if destination.id == parent_id -> Some(SameParent)
    _, _, _ ->
      case destination_is_descendant, destination.state, accepts_children {
        True, _, _ -> Some(SelfOrDescendant)
        _, Closed, _ -> Some(ClosedDestination)
        _, _, False -> Some(DestinationContainsTasks)
        _, _, True -> None
      }
  }
}

pub fn move_blocked_reason_label(reason: MoveBlockedReason) -> String {
  case reason {
    SourceClosed -> "La tarjeta cerrada no se puede mover."
    AlreadyAtProjectRoot -> "Ya está en la raíz del proyecto."
    SameParent -> "Ya está dentro de esta tarjeta."
    ClosedDestination -> "La tarjeta de destino está cerrada."
    DestinationContainsTasks ->
      "Contiene tareas directas y no puede recibir subtarjetas."
    SelfOrDescendant ->
      "No se puede elegir la propia tarjeta ni una descendiente."
    DestinationNotFound -> "No se encontró el destino seleccionado."
    NoAvailableDestination -> "No hay destinos disponibles para esta tarjeta."
  }
}

pub fn invalid_move_explanation(
  card: Card,
  destination: Card,
  cards: List(Card),
) -> String {
  case move_blocked_reason(card, destination, cards, []) {
    Some(reason) -> move_blocked_reason_label(reason)
    None -> "Destino disponible."
  }
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
  || card.closed_count > 0
  || card.has_new_notes
  || !list.is_empty(direct_child_cards)
  || !list.is_empty(direct_tasks)
}

fn accepts_child_cards(card: Card, cards: List(Card), tasks: List(Task)) -> Bool {
  let direct_tasks = case tasks {
    [] -> []
    _ -> list.filter(tasks, fn(task) { task.card_id == Some(card.id) })
  }

  case structure_for(card, direct_child_cards(card, cards), direct_tasks) {
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
