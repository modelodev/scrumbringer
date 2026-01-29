//// Database operations for user task views.

import gleam/result
import pog
import scrumbringer_server/sql

/// A user-task view record.
pub type UserTaskView {
  UserTaskView(user_id: Int, task_id: Int, last_viewed_at: String)
}

/// Updates last_viewed_at for a user and task.
pub fn touch_task_view(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(UserTaskView, pog.QueryError) {
  use returned <- result.try(sql.user_task_views_upsert(db, user_id, task_id))

  case returned.rows {
    [row, ..] ->
      Ok(UserTaskView(
        user_id: row.user_id,
        task_id: row.task_id,
        last_viewed_at: row.last_viewed_at,
      ))
    _ -> Error(pog.UnexpectedArgumentCount(1, 0))
  }
}
