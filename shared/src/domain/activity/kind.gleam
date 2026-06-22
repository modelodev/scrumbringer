//// User-facing activity event kinds.

import domain/audit_event/kind_codec as audit_kind

pub type ActivityKind {
  CardActivated
  CardClosed
  CardMoved
  TaskCreated
  TaskClaimed
  TaskReleased
  TaskClosed
  TaskDependencyAdded
  TaskDependencyRemoved
  NoteCreated
  NotePinned
  NoteUnpinned
  DueDateChanged
}

pub fn to_string(kind: ActivityKind) -> String {
  case kind {
    CardActivated -> "card_activated"
    CardClosed -> "card_closed"
    CardMoved -> "card_moved"
    TaskCreated -> "task_created"
    TaskClaimed -> "task_claimed"
    TaskReleased -> "task_released"
    TaskClosed -> "task_closed"
    TaskDependencyAdded -> "task_dependency_added"
    TaskDependencyRemoved -> "task_dependency_removed"
    NoteCreated -> "note_created"
    NotePinned -> "note_pinned"
    NoteUnpinned -> "note_unpinned"
    DueDateChanged -> "due_date_changed"
  }
}

pub fn parse(value: String) -> Result(ActivityKind, String) {
  case value {
    "card_activated" -> Ok(CardActivated)
    "card_closed" -> Ok(CardClosed)
    "card_moved" -> Ok(CardMoved)
    "task_created" -> Ok(TaskCreated)
    "task_claimed" -> Ok(TaskClaimed)
    "task_released" -> Ok(TaskReleased)
    "task_closed" -> Ok(TaskClosed)
    "task_dependency_added" -> Ok(TaskDependencyAdded)
    "task_dependency_removed" -> Ok(TaskDependencyRemoved)
    "note_created" -> Ok(NoteCreated)
    "note_pinned" -> Ok(NotePinned)
    "note_unpinned" -> Ok(NoteUnpinned)
    "due_date_changed" -> Ok(DueDateChanged)
    other -> Error(other)
  }
}

pub fn from_audit_kind(kind: audit_kind.Kind) -> ActivityKind {
  case kind {
    audit_kind.CardActivated -> CardActivated
    audit_kind.CardClosed -> CardClosed
    audit_kind.CardMoved -> CardMoved
    audit_kind.TaskCreated -> TaskCreated
    audit_kind.TaskClaimed -> TaskClaimed
    audit_kind.TaskReleased -> TaskReleased
    audit_kind.TaskClosed -> TaskClosed
    audit_kind.TaskDependencyAdded -> TaskDependencyAdded
    audit_kind.TaskDependencyRemoved -> TaskDependencyRemoved
    audit_kind.NoteCreated -> NoteCreated
    audit_kind.NotePinned -> NotePinned
    audit_kind.NoteUnpinned -> NoteUnpinned
    audit_kind.DueDateChanged -> DueDateChanged
  }
}
