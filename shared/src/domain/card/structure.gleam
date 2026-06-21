//// Card child structure for enforcing card hierarchy invariants.

import domain/card/id as card_id
import domain/task/id as task_id
import gleam/list

pub type CardStructureError {
  MixedChildKinds
}

pub type CardStructure {
  Empty
  CardGroup(List(card_id.CardId))
  TaskGroup(List(task_id.TaskId))
}

pub fn from_children(
  child_cards: List(card_id.CardId),
  child_tasks: List(task_id.TaskId),
) -> Result(CardStructure, CardStructureError) {
  case list.is_empty(child_cards), list.is_empty(child_tasks) {
    True, True -> Ok(Empty)
    False, True -> Ok(CardGroup(child_cards))
    True, False -> Ok(TaskGroup(child_tasks))
    False, False -> Error(MixedChildKinds)
  }
}
