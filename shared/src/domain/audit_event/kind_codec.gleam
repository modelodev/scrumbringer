//// Audit event kind codec.

import gleam/dynamic/decode

pub type Kind {
  TaskClaimed
  TaskReleased
  TaskDone
  CardActivated
  CardClosed
}

pub fn to_string(kind: Kind) -> String {
  case kind {
    TaskClaimed -> "task_claimed"
    TaskReleased -> "task_released"
    TaskDone -> "task_done"
    CardActivated -> "card_activated"
    CardClosed -> "card_closed"
  }
}

pub fn parse(value: String) -> Result(Kind, String) {
  case value {
    "task_claimed" -> Ok(TaskClaimed)
    "task_released" -> Ok(TaskReleased)
    "task_done" -> Ok(TaskDone)
    "card_activated" -> Ok(CardActivated)
    "card_closed" -> Ok(CardClosed)
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
