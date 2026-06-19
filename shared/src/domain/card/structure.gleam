//// Card child structure for enforcing card hierarchy invariants.

import domain/card/id as card_id
import domain/task/id as task_id

pub type CardStructure {
  Empty
  CardGroup(List(card_id.CardId))
  TaskGroup(List(task_id.TaskId))
}
