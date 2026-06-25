//// Database operations for audit event logging.
////
//// ## Mission
////
//// Persist audit events for task and card lifecycle activity feeds.
////
//// ## Responsibilities
////
//// - Map event types to DB values
//// - Insert audit event records against exactly one target
////
//// ## Non-responsibilities
////
//// - Event generation (see `repository/tasks/queries.gleam`)
//// - Metrics aggregation (see `use_case/rule_metrics_db.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for query execution

import gleam/result
import pog
import scrumbringer_server/sql

/// Event types recorded in the audit_events table.
pub type EventType {
  TaskCreated
  TaskClaimed
  TaskReleased
  TaskClosed
  NoteCreated
  NotePinned
  NoteUnpinned
  DueDateChanged
}

/// Converts an audit event type to its DB string value.
///
/// Example:
///   event_type_to_string(TaskClaimed)
pub fn event_type_to_string(event_type: EventType) -> String {
  case event_type {
    TaskCreated -> "task_created"
    TaskClaimed -> "task_claimed"
    TaskReleased -> "task_released"
    TaskClosed -> "task_closed"
    NoteCreated -> "note_created"
    NotePinned -> "note_pinned"
    NoteUnpinned -> "note_unpinned"
    DueDateChanged -> "due_date_changed"
  }
}

/// Inserts a new audit event record into the database.
///
/// ## Example
/// ```gleam
/// audit_events_db.insert(
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
  event_type: EventType,
) -> Result(Nil, pog.QueryError) {
  insert_for_task(db, org_id, project_id, task_id, actor_user_id, event_type)
}

/// Inserts a new event record for a task target.
pub fn insert_for_task(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  task_id: Int,
  actor_user_id: Int,
  event_type: EventType,
) -> Result(Nil, pog.QueryError) {
  sql.audit_events_insert_task(
    db,
    org_id,
    project_id,
    task_id,
    actor_user_id,
    event_type_to_string(event_type),
  )
  |> result.map(fn(_) { Nil })
}

/// Inserts a new event record for a card target.
pub fn insert_for_card(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  card_id: Int,
  actor_user_id: Int,
  event_type: EventType,
) -> Result(Nil, pog.QueryError) {
  sql.audit_events_insert_card(
    db,
    org_id,
    project_id,
    card_id,
    actor_user_id,
    event_type_to_string(event_type),
  )
  |> result.map(fn(_) { Nil })
}
