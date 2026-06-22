//// Note subject domain type.

import domain/card/id as card_id
import domain/task/id as task_id

pub type NoteSubject {
  CardNoteSubject(card_id: card_id.CardId)
  TaskNoteSubject(task_id: task_id.TaskId)
}

pub fn subject_id(subject: NoteSubject) -> Int {
  case subject {
    CardNoteSubject(card_id) -> card_id.to_int(card_id)
    TaskNoteSubject(task_id) -> task_id.to_int(task_id)
  }
}

pub fn subject_type(subject: NoteSubject) -> String {
  case subject {
    CardNoteSubject(_) -> "card"
    TaskNoteSubject(_) -> "task"
  }
}
