//// Card entity and structural invariants for the card tree model.

import domain/card/id as card_id
import domain/card/state
import domain/card/structure
import domain/project/id as project_id
import domain/task/id as task_id
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Card {
  Card(
    id: card_id.CardId,
    project_id: project_id.ProjectId,
    parent: Option(card_id.CardId),
    structure: structure.CardStructure,
    execution_state: state.CardExecutionState,
  )
}

pub type CardTree {
  CardTree(List(Card))
}

pub type ChildInsertError {
  CannotAddTaskToCardGroup
  CannotAddCardToTaskGroup
  CannotAddChildToClosedCard
  ParentNotFound
  ChildFromOtherProject
}

pub type CardMoveError {
  CannotMoveClosedCard
  CannotMoveIntoClosedCard
  DestinationDoesNotAcceptCards
  DestinationAtWrongDepth
  MoveWouldChangeDepth
  MoveWouldCreateCycle
  CardNotFound
  DestinationNotFound
}

pub fn add_task_child(
  card: Card,
  child_project_id: project_id.ProjectId,
  child_task_id: task_id.TaskId,
) -> Result(Card, ChildInsertError) {
  case is_closed(card), card.project_id == child_project_id, card.structure {
    True, _, _ -> Error(CannotAddChildToClosedCard)
    False, False, _ -> Error(ChildFromOtherProject)
    False, True, structure.Empty ->
      Ok(Card(..card, structure: structure.TaskGroup([child_task_id])))
    False, True, structure.TaskGroup(children) ->
      Ok(
        Card(
          ..card,
          structure: structure.TaskGroup(list.append(children, [child_task_id])),
        ),
      )
    False, True, structure.CardGroup(_) -> Error(CannotAddTaskToCardGroup)
  }
}

pub fn add_card_child(
  card: Card,
  child_project_id: project_id.ProjectId,
  child_card_id: card_id.CardId,
) -> Result(Card, ChildInsertError) {
  case is_closed(card), card.project_id == child_project_id, card.structure {
    True, _, _ -> Error(CannotAddChildToClosedCard)
    False, False, _ -> Error(ChildFromOtherProject)
    False, True, structure.Empty ->
      Ok(Card(..card, structure: structure.CardGroup([child_card_id])))
    False, True, structure.CardGroup(children) ->
      Ok(
        Card(
          ..card,
          structure: structure.CardGroup(list.append(children, [child_card_id])),
        ),
      )
    False, True, structure.TaskGroup(_) -> Error(CannotAddCardToTaskGroup)
  }
}

pub fn move_card_to_parent(
  card: Card,
  destination_parent: Option(card_id.CardId),
  tree: CardTree,
) -> Result(Card, CardMoveError) {
  case is_closed(card), destination_parent {
    True, _ -> Error(CannotMoveClosedCard)
    False, None -> Ok(Card(..card, parent: None))
    False, Some(destination_id) -> {
      case find_card(tree, destination_id) {
        Error(_) -> Error(DestinationNotFound)
        Ok(destination) ->
          case
            is_closed(destination),
            accepts_card_children(destination),
            is_descendant(destination.id, card.id, tree)
          {
            True, _, _ -> Error(CannotMoveIntoClosedCard)
            False, False, _ -> Error(DestinationDoesNotAcceptCards)
            False, True, True -> Error(MoveWouldCreateCycle)
            False, True, False -> Ok(Card(..card, parent: Some(destination_id)))
          }
      }
    }
  }
}

fn is_closed(card: Card) -> Bool {
  case card.execution_state {
    state.Closed(..) -> True
    _ -> False
  }
}

fn accepts_card_children(card: Card) -> Bool {
  case card.structure {
    structure.Empty | structure.CardGroup(_) -> True
    structure.TaskGroup(_) -> False
  }
}

fn is_descendant(
  candidate_id: card_id.CardId,
  ancestor_id: card_id.CardId,
  tree: CardTree,
) -> Bool {
  case find_card(tree, candidate_id) {
    Error(_) -> False
    Ok(candidate) ->
      case candidate.parent {
        None -> False
        Some(parent_id) if parent_id == ancestor_id -> True
        Some(parent_id) -> is_descendant(parent_id, ancestor_id, tree)
      }
  }
}

fn find_card(tree: CardTree, target_id: card_id.CardId) -> Result(Card, Nil) {
  let CardTree(cards) = tree
  find_card_in(cards, target_id)
}

fn find_card_in(
  cards: List(Card),
  target_id: card_id.CardId,
) -> Result(Card, Nil) {
  case cards {
    [] -> Error(Nil)
    [first, ..rest] ->
      case first.id == target_id {
        True -> Ok(first)
        False -> find_card_in(rest, target_id)
      }
  }
}
