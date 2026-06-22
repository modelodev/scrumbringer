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
//// - Business validation (see `use_case/task_workflow_actor.gleam`)
////
//// ## Relations
////
//// - **mappers.gleam**: Converts query results to Task records
//// - **sql.gleam**: Squirrel-generated query functions
//// - **audit_events_db.gleam**: Records audit events

import domain/field_update
import domain/task.{type Task}
import domain/task_status
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/option as option_helpers
import pog
import scrumbringer_server/repository/tasks/mappers
import scrumbringer_server/sql
import scrumbringer_server/use_case/audit_events_db
import scrumbringer_server/use_case/service_error
import scrumbringer_server/use_case/work_sessions_db

/// Result of releasing all claimed tasks for a user within a project.
pub type ReleaseAllResult {
  ReleaseAllResult(released_count: Int, task_ids: List(Int))
}

const no_optional_id_filter_value = 0

const no_optional_id_create_value = 0

const no_search_filter_value = ""

const unchanged_text_update_value = "__unset__"

const unchanged_positive_int_update_value = 0

const unchanged_optional_id_update_value = -1

const cleared_optional_id_update_value = 0

/// List tasks for a project with optional filters.
/// Story 5.4: Now uses user_id for has_new_notes calculation.
pub fn list_tasks_for_project(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  status: Option(task_status.TaskPhase),
  type_id: Option(Int),
  capability_id: Option(Int),
  q: Option(String),
  blocked: Option(Bool),
) -> Result(List(Task), service_error.ServiceError) {
  use returned <- result.try(
    sql.tasks_list(
      db,
      project_id,
      status_filter_to_db_string(status),
      optional_id_filter_value(type_id),
      optional_id_filter_value(capability_id),
      search_filter_value(q),
      user_id,
      blocked_filter_to_db(blocked),
    )
    |> result.map_error(service_error.DbError),
  )

  returned.rows
  |> list.try_map(mappers.from_list_row)
}

fn blocked_filter_to_db(value: Option(Bool)) -> String {
  case value {
    None -> ""
    Some(True) -> "true"
    Some(False) -> "false"
  }
}

fn status_filter_to_db_string(status: Option(task_status.TaskPhase)) -> String {
  case status {
    None -> ""
    Some(value) -> task_status.to_db_status(value)
  }
}

fn optional_id_filter_value(value: Option(Int)) -> Int {
  option_helpers.option_to_value(value, no_optional_id_filter_value)
}

fn search_filter_value(value: Option(String)) -> String {
  option_helpers.option_to_value(value, no_search_filter_value)
}

fn optional_id_create_value(value: Option(Int)) -> Int {
  option_helpers.option_to_value(value, no_optional_id_create_value)
}

fn text_update_value(value: Option(String)) -> String {
  option_helpers.option_to_value(value, unchanged_text_update_value)
}

fn priority_update_value(value: Option(Int)) -> Int {
  option_helpers.option_to_value(value, unchanged_positive_int_update_value)
}

fn type_id_update_value(value: Option(Int)) -> Int {
  option_helpers.option_to_value(value, unchanged_positive_int_update_value)
}

fn parent_card_id_update_value(
  value: field_update.FieldUpdate(Option(Int)),
) -> Int {
  optional_id_update_value(value)
}

fn card_id_update_value(value: field_update.FieldUpdate(Option(Int))) -> Int {
  optional_id_update_value(value)
}

fn optional_id_update_value(value: field_update.FieldUpdate(Option(Int))) -> Int {
  case value {
    field_update.Unchanged -> unchanged_optional_id_update_value
    field_update.Set(None) -> cleared_optional_id_update_value
    field_update.Set(Some(id)) -> id
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
  parent_card_id: Option(Int),
  created_from_rule_id: Option(Int),
) -> Result(Task, service_error.ServiceError) {
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
        optional_id_create_value(card_id),
        optional_id_create_value(parent_card_id),
        optional_id_create_value(created_from_rule_id),
      )
    {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        use task <- result.try(mappers.from_create_row(row))

        use _ <- result.try(
          audit_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            created_by,
            audit_events_db.TaskCreated,
          )
          |> result.map_error(service_error.DbError),
        )

        Ok(task)
      }

      Ok(pog.Returned(rows: [], ..)) ->
        Error(service_error.InvalidReference("type_id"))
      Error(e) -> Error(service_error.DbError(e))
    }
  })
  |> result.map_error(transaction_error_to_create_task_error)
}

/// Get a task by ID for a specific user.
pub fn get_task_for_user(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Task, service_error.ServiceError) {
  case sql.tasks_get_for_user(db, task_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> mappers.from_get_row(row)
    Ok(pog.Returned(rows: [], ..)) -> Error(service_error.NotFound)
    Error(e) -> Error(service_error.DbError(e))
  }
}

/// Delete a task only when it has no operational history.
pub fn delete_task(
  db: pog.Connection,
  task_id: Int,
) -> Result(Int, service_error.ServiceError) {
  case sql.tasks_delete(db, task_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row.id)
    Ok(pog.Returned(rows: [], ..)) ->
      Error(service_error.Conflict("task_has_operational_history"))
    Error(e) -> Error(service_error.DbError(e))
  }
}

/// Update an available task or a task claimed by the caller.
pub fn update_editable_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  title: Option(String),
  description: Option(String),
  priority: Option(Int),
  type_id: Option(Int),
  parent_card_id: field_update.FieldUpdate(Option(Int)),
  card_id: field_update.FieldUpdate(Option(Int)),
  version: Int,
) -> Result(Task, service_error.ServiceError) {
  case
    sql.tasks_update(
      db,
      task_id,
      user_id,
      text_update_value(title),
      text_update_value(description),
      priority_update_value(priority),
      type_id_update_value(type_id),
      parent_card_id_update_value(parent_card_id),
      card_id_update_value(card_id),
      version,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> mappers.from_update_row(row)
    Ok(pog.Returned(rows: [], ..)) -> Error(service_error.NotFound)
    Error(e) -> Error(service_error.DbError(e))
  }
}

/// Claim an available task for a user.
pub fn claim_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, service_error.ServiceError) {
  pog.transaction(db, fn(tx) {
    case sql.tasks_claim(tx, task_id, user_id, version) {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        use task <- result.try(mappers.from_claim_row(row))

        use _ <- result.try(
          audit_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            audit_events_db.TaskClaimed,
          )
          |> result.map_error(service_error.DbError),
        )

        Ok(task)
      }
      Ok(pog.Returned(rows: [], ..)) -> Error(service_error.NotFound)
      Error(e) -> Error(service_error.DbError(e))
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
) -> Result(Task, service_error.ServiceError) {
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
        use task <- result.try(mappers.from_release_row(row))

        use _ <- result.try(
          audit_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            audit_events_db.TaskReleased,
          )
          |> result.map_error(service_error.DbError),
        )

        Ok(task)
      }
      Ok(pog.Returned(rows: [], ..)) -> Error(service_error.NotFound)
      Error(e) -> Error(service_error.DbError(e))
    }
  })
  |> result.map_error(transaction_error_to_not_found_or_db_error)
}

/// Release all claimed tasks for a user within a project.
pub fn release_all_tasks_for_user(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  target_user_id: Int,
  actor_user_id: Int,
) -> Result(ReleaseAllResult, service_error.ServiceError) {
  pog.transaction(db, fn(tx) {
    case sql.tasks_release_all(tx, project_id, target_user_id) {
      Ok(pog.Returned(rows: rows, ..)) -> {
        let task_ids = rows |> list.map(fn(row) { row.id })
        task_ids
        |> list.each(fn(task_id) {
          let _ =
            work_sessions_db.close_session_for_task(
              tx,
              target_user_id,
              task_id,
              "task_released",
            )
          Nil
        })

        use _ <- result.try(
          task_ids
          |> list.try_map(fn(task_id) {
            audit_events_db.insert(
              tx,
              org_id,
              project_id,
              task_id,
              actor_user_id,
              audit_events_db.TaskReleased,
            )
            |> result.map_error(service_error.DbError)
          })
          |> result.map(fn(_) { Nil }),
        )

        Ok(ReleaseAllResult(
          released_count: list.length(task_ids),
          task_ids: task_ids,
        ))
      }
      Error(e) -> Error(service_error.DbError(e))
    }
  })
  |> result.map_error(transaction_error_to_release_all_error)
}

/// Complete a claimed task.
pub fn complete_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, service_error.ServiceError) {
  pog.transaction(db, fn(tx) {
    // Best effort: close any active work session before complete.
    let _ =
      work_sessions_db.close_session_for_task(
        tx,
        user_id,
        task_id,
        "task_closed",
      )

    case sql.tasks_complete(tx, task_id, user_id, version) {
      Ok(pog.Returned(rows: [row, ..], ..)) -> {
        use task <- result.try(mappers.from_complete_row(row))

        use _ <- result.try(
          audit_events_db.insert(
            tx,
            org_id,
            task.project_id,
            task.id,
            user_id,
            audit_events_db.TaskClosed,
          )
          |> result.map_error(service_error.DbError),
        )

        Ok(task)
      }
      Ok(pog.Returned(rows: [], ..)) -> Error(service_error.NotFound)
      Error(e) -> Error(service_error.DbError(e))
    }
  })
  |> result.map_error(transaction_error_to_not_found_or_db_error)
}

// =============================================================================
// Transaction Error Helpers
// =============================================================================

fn transaction_error_to_create_task_error(
  error: pog.TransactionError(service_error.ServiceError),
) -> service_error.ServiceError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> service_error.DbError(err)
  }
}

fn transaction_error_to_not_found_or_db_error(
  error: pog.TransactionError(service_error.ServiceError),
) -> service_error.ServiceError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> service_error.DbError(err)
  }
}

fn transaction_error_to_release_all_error(
  error: pog.TransactionError(service_error.ServiceError),
) -> service_error.ServiceError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> service_error.DbError(err)
  }
}
