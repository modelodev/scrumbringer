//// Activity feed subject domain type.

import domain/card/id as card_id
import domain/task/id as task_id

pub type ActivitySubject {
  ActivityCard(card_id: card_id.CardId)
  ActivityTask(task_id: task_id.TaskId)
}

pub fn subject_id(subject: ActivitySubject) -> Int {
  case subject {
    ActivityCard(card_id) -> card_id.to_int(card_id)
    ActivityTask(task_id) -> task_id.to_int(task_id)
  }
}

pub fn subject_type(subject: ActivitySubject) -> String {
  case subject {
    ActivityCard(_) -> "card"
    ActivityTask(_) -> "task"
  }
}
