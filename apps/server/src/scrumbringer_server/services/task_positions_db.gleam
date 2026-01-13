import gleam/list
import gleam/result
import pog
import scrumbringer_server/sql

pub type TaskPosition {
  TaskPosition(task_id: Int, user_id: Int, x: Int, y: Int, updated_at: String)
}

pub type UpsertPositionError {
  DbError(pog.QueryError)
  UnexpectedEmptyResult
}

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

pub fn upsert_position(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  x: Int,
  y: Int,
) -> Result(TaskPosition, UpsertPositionError) {
  case sql.task_positions_upsert(db, task_id, user_id, x, y) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(position_from_upsert_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(UnexpectedEmptyResult)
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
