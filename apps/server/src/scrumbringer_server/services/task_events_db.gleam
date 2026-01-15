import gleam/result
import pog
import scrumbringer_server/sql

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
