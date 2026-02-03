//// Database operations for task positions on the board.
////
//// Task positions track where each user has placed tasks on their personal
//// board view. Each user can have their own arrangement of tasks.

import gleam/list
import gleam/result
import pog
import scrumbringer_server/services/service_error.{
  type ServiceError, DbError, Unexpected,
}
import scrumbringer_server/sql

/// A task's position on a user's board view.
pub type TaskPosition {
  TaskPosition(task_id: Int, user_id: Int, x: Int, y: Int, updated_at: String)
}

/// Lists all task positions for a user in a project.
///
/// ## Example
/// ```gleam
/// case task_positions_db.list_positions_for_user(db, user_id, project_id) {
///   Ok(positions) -> restore_board_layout(positions)
///   Error(_) -> use_default_layout()
/// }
/// ```
pub fn list_positions_for_user(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Result(List(TaskPosition), pog.QueryError) {
  use returned <- result.try(sql.task_positions_list_for_user(
    db,
    user_id,
    project_id,
  ))

  returned.rows
  |> list.map(position_from_list_row)
  |> Ok
}

/// Updates or inserts a task's position on a user's board.
///
/// ## Example
/// ```gleam
/// case task_positions_db.upsert_position(db, task_id, user_id, 100, 250) {
///   Ok(pos) -> Ok(PositionSaved)
///   Error(_) -> Error(SaveFailed)
/// }
/// ```
pub fn upsert_position(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  x: Int,
  y: Int,
) -> Result(TaskPosition, ServiceError) {
  case sql.task_positions_upsert(db, task_id, user_id, x, y) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(position_from_upsert_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(Unexpected("empty_result"))
    Error(e) -> Error(DbError(e))
  }
}

fn position_from_list_row(row: sql.TaskPositionsListForUserRow) -> TaskPosition {
  TaskPosition(
    task_id: row.task_id,
    user_id: row.user_id,
    x: row.x,
    y: row.y,
    updated_at: row.updated_at,
  )
}

fn position_from_upsert_row(row: sql.TaskPositionsUpsertRow) -> TaskPosition {
  TaskPosition(
    task_id: row.task_id,
    user_id: row.user_id,
    x: row.x,
    y: row.y,
    updated_at: row.updated_at,
  )
}
