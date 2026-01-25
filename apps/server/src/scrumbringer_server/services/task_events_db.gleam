//// Database operations for task event logging.
////
//// Task events track actions performed on tasks (claim, release, complete, etc.)
//// for audit and analytics purposes.

import gleam/result
import pog
import scrumbringer_server/sql

/// Task event types recorded in the task_events table.
pub type TaskEventType {
  TaskCreated
  TaskClaimed
  TaskReleased
  TaskCompleted
}

pub fn event_type_to_string(event_type: TaskEventType) -> String {
  case event_type {
    TaskCreated -> "task_created"
    TaskClaimed -> "task_claimed"
    TaskReleased -> "task_released"
    TaskCompleted -> "task_completed"
  }
}

/// Inserts a new task event record into the database.
///
/// ## Example
/// ```gleam
/// task_events_db.insert(
///   db,
///   org_id,
///   project_id,
///   task_id,
///   user_id,
///   TaskClaimed,
/// )
/// // => Ok(Nil)
/// ```
pub fn insert(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  task_id: Int,
  actor_user_id: Int,
  event_type: TaskEventType,
) -> Result(Nil, pog.QueryError) {
  sql.task_events_insert(
    db,
    org_id,
    project_id,
    task_id,
    actor_user_id,
    event_type_to_string(event_type),
  )
  |> result.map(fn(_) { Nil })
}
