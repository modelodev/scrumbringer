//// Audit event kind codec.

import gleam/dynamic/decode

pub type Kind {
  TaskCreated
  TaskClaimed
  TaskReleased
  TaskClosed
  CardActivated
  CardClosed
  CardMoved
  TaskDependencyAdded
  TaskDependencyRemoved
}

pub fn to_string(kind: Kind) -> String {
  case kind {
    TaskCreated -> "task_created"
    TaskClaimed -> "task_claimed"
    TaskReleased -> "task_released"
    TaskClosed -> "task_closed"
    CardActivated -> "card_activated"
    CardClosed -> "card_closed"
    CardMoved -> "card_moved"
    TaskDependencyAdded -> "task_dependency_added"
    TaskDependencyRemoved -> "task_dependency_removed"
  }
}

pub fn parse(value: String) -> Result(Kind, String) {
  case value {
    "task_created" -> Ok(TaskCreated)
    "task_claimed" -> Ok(TaskClaimed)
    "task_released" -> Ok(TaskReleased)
    "task_closed" -> Ok(TaskClosed)
    "card_activated" -> Ok(CardActivated)
    "card_closed" -> Ok(CardClosed)
    "card_moved" -> Ok(CardMoved)
    "task_dependency_added" -> Ok(TaskDependencyAdded)
    "task_dependency_removed" -> Ok(TaskDependencyRemoved)
    other -> Error(other)
  }
}

pub fn decoder() -> decode.Decoder(Kind) {
  use raw <- decode.then(decode.string)
  case parse(raw) {
    Ok(kind) -> decode.success(kind)
    Error(other) -> decode.failure(TaskClaimed, "audit event kind " <> other)
  }
}
