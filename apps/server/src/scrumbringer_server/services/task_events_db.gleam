//// Database operations for task event logging.
////
//// Task events track actions performed on tasks (claim, release, complete, etc.)
//// for audit and analytics purposes.

import gleam/result
import pog
import scrumbringer_server/sql

/// Inserts a new task event record into the database.
///
/// ## Example
/// ```gleam
/// task_events_db.insert(db, org_id, project_id, task_id, user_id, "claimed")
/// // => Ok(Nil)
/// ```
pub fn insert(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  task_id: Int,
  actor_user_id: Int,
  event_type: String,
) -> Result(Nil, pog.QueryError) {
  sql.task_events_insert(
    db,
    org_id,
    project_id,
    task_id,
    actor_user_id,
    event_type,
  )
  |> result.map(fn(_) { Nil })
}
