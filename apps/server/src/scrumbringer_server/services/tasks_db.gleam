import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/domain/task_status.{type TaskStatus}
import scrumbringer_server/services/now_working_db
import scrumbringer_server/services/task_events_db
import scrumbringer_server/sql

/// Task record with type-safe status.
///
/// The `status` field uses the `TaskStatus` ADT instead of strings,
/// enabling compile-time verification of status handling.
///
/// ## Example
///
/// ```gleam
/// case task.status {
///   task_status.Available -> "Can be claimed"
///   task_status.Claimed(task_status.Ongoing) -> "Being worked on"
///   task_status.Claimed(task_status.Taken) -> "Claimed but idle"
///   task_status.Completed -> "Done"
/// }
/// ```
pub type Task {
  Task(
    id: Int,
    project_id: Int,
    type_id: Int,
    type_name: String,
    type_icon: String,
    title: String,
    description: Option(String),
    priority: Int,
    status: TaskStatus,
    ongoing_by_user_id: Option(Int),
    created_by: Int,
    claimed_by: Option(Int),
    claimed_at: Option(String),
    completed_at: Option(String),
    created_at: String,
    version: Int,
  )
}

pub type CreateTaskError {
  InvalidTypeId
  CreateDbError(pog.QueryError)
}

pub type NotFoundOrDbError {
  NotFound
  DbError(pog.QueryError)
}

pub fn list_tasks_for_project(
  db: pog.Connection,
  project_id: Int,
  _user_id: Int,
  status: String,
  type_id: Int,
  capability_id: Int,
  q: String,
) -> Result(List(Task), pog.QueryError) {
  use returned <- result.try(sql.tasks_list(
    db,
    project_id,
    status,
    type_id,
    capability_id,
    q,
  ))

  returned.rows
  |> list.map(task_from_list_row)
  |> Ok
}

pub fn create_task(
  db: pog.Connection,
  org_id: Int,
  type_id: Int,
  project_id: Int,
  title: String,
  description: String,
  priority: Int,
  created_by: Int,
) -> Result(Task, CreateTaskError) {
  pog.transaction(db, fn(tx) {
    case
      sql.tasks_create(
        tx,
        type_id,
        project_id,
        title,
        description,
        priority,
        created_by,
      )
    {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        let task = task_from_create_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            created_by,
            "task_created",
          )
          |> result.map_error(CreateDbError),
        )

        Ok(task)
      }

      Ok(pog.Returned(rows: [], ..)) -> Error(InvalidTypeId)
      Error(e) -> Error(CreateDbError(e))
    }
  })
  |> result.map_error(transaction_error_to_create_task_error)
}

fn transaction_error_to_create_task_error(
  error: pog.TransactionError(CreateTaskError),
) -> CreateTaskError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> CreateDbError(err)
  }
}

fn transaction_error_to_not_found_or_db_error(
  error: pog.TransactionError(NotFoundOrDbError),
) -> NotFoundOrDbError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> DbError(err)
  }
}

pub fn get_task_for_user(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Task, NotFoundOrDbError) {
  case sql.tasks_get_for_user(db, task_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

pub fn update_task_claimed_by_user(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  case
    sql.tasks_update(
      db,
      task_id,
      user_id,
      title,
      description,
      priority,
      type_id,
      version,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_update_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

pub fn claim_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  pog.transaction(db, fn(tx) {
    case sql.tasks_claim(tx, task_id, user_id, version) {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        let task = task_from_claim_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            "task_claimed",
          )
          |> result.map_error(DbError),
        )

        Ok(task)
      }
      Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
      Error(e) -> Error(DbError(e))
    }
  })
  |> result.map_error(transaction_error_to_not_found_or_db_error)
}

pub fn release_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  pog.transaction(db, fn(tx) {
    // Best effort: if this task was "now working", clear it before release.
    let _ = now_working_db.pause_if_matches(tx, user_id, task_id)

    case sql.tasks_release(tx, task_id, user_id, version) {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        let task = task_from_release_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            "task_released",
          )
          |> result.map_error(DbError),
        )

        Ok(task)
      }
      Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
      Error(e) -> Error(DbError(e))
    }
  })
  |> result.map_error(transaction_error_to_not_found_or_db_error)
}

pub fn complete_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  pog.transaction(db, fn(tx) {
    // Best effort: if this task was "now working", clear it before complete.
    let _ = now_working_db.pause_if_matches(tx, user_id, task_id)

    case sql.tasks_complete(tx, task_id, user_id, version) {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        let task = task_from_complete_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            "task_completed",
          )
          |> result.map_error(DbError),
        )

        Ok(task)
      }
      Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
      Error(e) -> Error(DbError(e))
    }
  })
  |> result.map_error(transaction_error_to_not_found_or_db_error)
}

fn task_from_list_row(row: sql.TasksListRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_get_row(row: sql.TasksGetForUserRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_create_row(row: sql.TasksCreateRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_update_row(row: sql.TasksUpdateRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_claim_row(row: sql.TasksClaimRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_release_row(row: sql.TasksReleaseRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_complete_row(row: sql.TasksCompleteRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_fields(
  id id: Int,
  project_id project_id: Int,
  type_id type_id: Int,
  type_name type_name: String,
  type_icon type_icon: String,
  title title: String,
  description description: String,
  priority priority: Int,
  status status: String,
  is_ongoing is_ongoing: Bool,
  ongoing_by_user_id ongoing_by_user_id: Int,
  created_by created_by: Int,
  claimed_by claimed_by: Int,
  claimed_at claimed_at: String,
  completed_at completed_at: String,
  created_at created_at: String,
  version version: Int,
) -> Task {
  Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    type_name: type_name,
    type_icon: type_icon,
    title: title,
    description: string_option(description),
    priority: priority,
    status: task_status.from_db(status, is_ongoing),
    ongoing_by_user_id: int_option(ongoing_by_user_id),
    created_by: created_by,
    claimed_by: int_option(claimed_by),
    claimed_at: string_option(claimed_at),
    completed_at: string_option(completed_at),
    created_at: created_at,
    version: version,
  )
}

fn int_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    v -> Some(v)
  }
}

fn string_option(value: String) -> Option(String) {
  case value {
    "" -> None
    v -> Some(v)
  }
}
