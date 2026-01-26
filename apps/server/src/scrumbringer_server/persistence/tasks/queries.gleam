//// Task database queries for Scrumbringer server.
////
//// ## Mission
////
//// Provides database access for tasks including CRUD operations,
//// state transitions (claim, release, complete), and listing with filters.
////
//// ## Responsibilities
////
//// - Execute SQL queries via squirrel-generated modules
//// - Handle transactions for multi-step operations
//// - Record task events for audit trail
////
//// ## Non-responsibilities
////
//// - Row-to-domain mapping (see `mappers.gleam`)
//// - HTTP handling (see `http/tasks.gleam`)
//// - Business validation (see `services/task_workflow_actor.gleam`)
////
//// ## Relations
////
//// - **mappers.gleam**: Converts query results to Task records
//// - **sql.gleam**: Squirrel-generated query functions
//// - **task_events_db.gleam**: Records audit events

import domain/task_status
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/persistence/tasks/mappers.{type Task}
import scrumbringer_server/services/task_events_db
import scrumbringer_server/services/work_sessions_db
import scrumbringer_server/sql

/// Error when task creation fails.
pub type CreateTaskError {
  InvalidTypeId
  InvalidCardId
  CreateDbError(pog.QueryError)
}

/// Error when task not found or DB error.
pub type NotFoundOrDbError {
  NotFound
  DbError(pog.QueryError)
}

/// List tasks for a project with optional filters.
pub fn list_tasks_for_project(
  db: pog.Connection,
  project_id: Int,
  _user_id: Int,
  status: Option(task_status.TaskStatus),
  type_id: Option(Int),
  capability_id: Option(Int),
  q: Option(String),
) -> Result(List(Task), pog.QueryError) {
  use returned <- result.try(sql.tasks_list(
    db,
    project_id,
    status_filter_to_db_string(status),
    option_int_to_db(type_id),
    option_int_to_db(capability_id),
    option_string_to_db(q),
  ))

  returned.rows
  |> list.map(mappers.from_list_row)
  |> Ok
}

fn status_filter_to_db_string(status: Option(task_status.TaskStatus)) -> String {
  case status {
    None -> ""
    Some(value) -> task_status.to_db_status(value)
  }
}

/// Create a new task in the database.
pub fn create_task(
  db: pog.Connection,
  org_id: Int,
  type_id: Int,
  project_id: Int,
  title: String,
  description: String,
  priority: Int,
  created_by: Int,
  card_id: Option(Int),
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
        option_int_to_db(card_id),
      )
    {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        let task = mappers.from_create_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            created_by,
            task_events_db.TaskCreated,
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

/// Get a task by ID for a specific user.
pub fn get_task_for_user(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Task, NotFoundOrDbError) {
  case sql.tasks_get_for_user(db, task_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(mappers.from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Update a task that is claimed by the user.
pub fn update_task_claimed_by_user(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  title: Option(String),
  description: Option(String),
  priority: Option(Int),
  type_id: Option(Int),
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  case
    sql.tasks_update(
      db,
      task_id,
      user_id,
      option_string_update_to_db(title),
      option_string_update_to_db(description),
      option_int_to_db(priority),
      option_int_to_db(type_id),
      version,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(mappers.from_update_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn option_int_to_db(value: Option(Int)) -> Int {
  case value {
    None -> 0
    Some(actual) -> actual
  }
}

fn option_string_to_db(value: Option(String)) -> String {
  case value {
    None -> ""
    Some(actual) -> actual
  }
}

fn option_string_update_to_db(value: Option(String)) -> String {
  case value {
    None -> "__unset__"
    Some(actual) -> actual
  }
}

/// Claim an available task for a user.
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
        let task = mappers.from_claim_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            task_events_db.TaskClaimed,
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

/// Release a claimed task back to available.
pub fn release_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  pog.transaction(db, fn(tx) {
    // Best effort: close any active work session before release.
    let _ =
      work_sessions_db.close_session_for_task(
        tx,
        user_id,
        task_id,
        "task_released",
      )

    case sql.tasks_release(tx, task_id, user_id, version) {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        let task = mappers.from_release_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            task_events_db.TaskReleased,
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

/// Complete a claimed task.
pub fn complete_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  pog.transaction(db, fn(tx) {
    // Best effort: close any active work session before complete.
    let _ =
      work_sessions_db.close_session_for_task(
        tx,
        user_id,
        task_id,
        "task_completed",
      )

    case sql.tasks_complete(tx, task_id, user_id, version) {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        let task = mappers.from_complete_row(row)

        use _ <- result.try(
          task_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            task_events_db.TaskCompleted,
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

// =============================================================================
// Transaction Error Helpers
// =============================================================================

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
