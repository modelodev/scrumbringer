import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import pog

pub type ActiveTask {
  ActiveTask(task_id: Int, project_id: Int, started_at: String)
}

pub type StartError {
  NotClaimed
  DbError(pog.QueryError)
}

pub fn get_active_task(
  db: pog.Connection,
  user_id: Int,
) -> Result(Option(ActiveTask), pog.QueryError) {
  let decoder = {
    use task_id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use started_at <- decode.field(2, decode.string)
    decode.success(ActiveTask(task_id:, project_id:, started_at:))
  }

  use returned <- result.try(
    pog.query(
      "select task_id, project_id, coalesce(to_char(started_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as started_at from user_now_working where user_id = $1 and task_id is not null",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [row, ..] -> Ok(Some(row))
    _ -> Ok(None)
  }
}

pub fn start(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(ActiveTask, StartError) {
  // Ensure the task is currently claimed by this user.
  let decoder = {
    use project_id <- decode.field(0, decode.int)
    decode.success(project_id)
  }

  let claimed =
    pog.query(
      "select project_id from tasks where id = $1 and status = 'claimed' and claimed_by = $2",
    )
    |> pog.parameter(pog.int(task_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(decoder)
    |> pog.execute(db)

  case claimed {
    Error(e) -> Error(DbError(e))

    Ok(pog.Returned(rows: [], ..)) -> Error(NotClaimed)

    Ok(pog.Returned(rows: [project_id, ..], ..)) -> {
      let write =
        pog.query(
          "insert into user_now_working (user_id, task_id, project_id, started_at, updated_at)\nvalues ($1, $2, $3, now(), now())\non conflict (user_id) do update\nset task_id = excluded.task_id, project_id = excluded.project_id, started_at = excluded.started_at, updated_at = now()\nreturning task_id, project_id, coalesce(to_char(started_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as started_at",
        )
        |> pog.parameter(pog.int(user_id))
        |> pog.parameter(pog.int(task_id))
        |> pog.parameter(pog.int(project_id))

      let decoder = {
        use task_id <- decode.field(0, decode.int)
        use project_id <- decode.field(1, decode.int)
        use started_at <- decode.field(2, decode.string)
        decode.success(ActiveTask(task_id:, project_id:, started_at:))
      }

      case write |> pog.returning(decoder) |> pog.execute(db) {
        Error(e) -> Error(DbError(e))
        Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row)
        Ok(pog.Returned(rows: [], ..)) -> Error(NotClaimed)
      }
    }
  }
}

pub fn pause(db: pog.Connection, user_id: Int) -> Result(Nil, pog.QueryError) {
  pog.query(
    "insert into user_now_working (user_id, task_id, project_id, started_at, updated_at)\nvalues ($1, null, null, null, now())\non conflict (user_id) do update\nset task_id = null, project_id = null, started_at = null, updated_at = now()",
  )
  |> pog.parameter(pog.int(user_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

pub fn pause_if_matches(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(Nil, pog.QueryError) {
  pog.query(
    "update user_now_working set task_id = null, project_id = null, started_at = null, updated_at = now() where user_id = $1 and task_id = $2",
  )
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.int(task_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

pub fn as_of(db: pog.Connection) -> Result(String, pog.QueryError) {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }

  use returned <- result.try(
    pog.query(
      "select to_char(now() at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')",
    )
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [value, ..] -> Ok(value)
    _ -> Ok("")
  }
}
