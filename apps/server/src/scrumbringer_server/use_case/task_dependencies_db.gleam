////
//// Task dependency repository helpers.
////

import gleam/list
import gleam/option.{type Option}
import gleam/result
import helpers/option as option_helpers
import pog

import domain/task.{type TaskDependency, TaskDependency}
import domain/task/state as task_state
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/service_error.{
  type ServiceError, DbError, NotFound,
}

pub fn list_dependencies_for_task(
  db: pog.Connection,
  task_id: Int,
) -> Result(List(TaskDependency), ServiceError) {
  case sql.task_dependencies_list(db, task_id) {
    Ok(pog.Returned(rows: rows, ..)) ->
      rows
      |> list.try_map(dependency_from_list_row)
    Error(e) -> Error(DbError(e))
  }
}

pub fn list_dependency_ids_for_task(
  db: pog.Connection,
  task_id: Int,
) -> Result(List(Int), ServiceError) {
  case list_dependencies_for_task(db, task_id) {
    Ok(deps) ->
      deps
      |> list.map(fn(dep) {
        let TaskDependency(depends_on_task_id: depends_on_task_id, ..) = dep
        depends_on_task_id
      })
      |> Ok
    Error(e) -> Error(e)
  }
}

pub fn create_dependency(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
  created_by: Int,
) -> Result(TaskDependency, ServiceError) {
  case
    sql.task_dependencies_create(db, task_id, depends_on_task_id, created_by)
  {
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(persisted_field.returned_row(
        rows,
        "task_dependencies.create_dependency",
      ))
      dependency_from_create_row(row)
    }
    Error(e) -> Error(DbError(e))
  }
}

pub fn delete_dependency(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
) -> Result(Nil, ServiceError) {
  case sql.task_dependencies_delete(db, task_id, depends_on_task_id) {
    Ok(pog.Returned(rows: [_row, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn dependency_from_list_row(
  row: sql.TaskDependenciesListRow,
) -> Result(TaskDependency, ServiceError) {
  dependency_from_fields(
    row.task_id,
    row.title,
    row.status,
    row.is_ongoing,
    row.claimed_by_user_id,
    row.claimed_at,
    row.completed_at,
    row.claimed_by,
  )
}

fn dependency_from_create_row(
  row: sql.TaskDependenciesCreateRow,
) -> Result(TaskDependency, ServiceError) {
  dependency_from_fields(
    row.task_id,
    row.title,
    row.status,
    row.is_ongoing,
    row.claimed_by_user_id,
    row.claimed_at,
    row.completed_at,
    row.claimed_by,
  )
}

fn dependency_from_fields(
  task_id: Int,
  title: String,
  status_value: String,
  is_ongoing: Bool,
  claimed_by_user_id: Int,
  claimed_at: String,
  completed_at: String,
  claimed_by: String,
) -> Result(TaskDependency, ServiceError) {
  use state <- result.try(parse_dependency_state(
    status_value,
    is_ongoing,
    option_helpers.int_to_option(claimed_by_user_id),
    option_helpers.string_to_option(claimed_at),
    option_helpers.string_to_option(completed_at),
  ))
  Ok(TaskDependency(
    depends_on_task_id: task_id,
    title: title,
    state: state,
    claimed_by: option_helpers.string_to_option(claimed_by),
  ))
}

fn parse_dependency_state(
  status: String,
  is_ongoing: Bool,
  claimed_by: Option(Int),
  claimed_at: Option(String),
  completed_at: Option(String),
) -> Result(task_state.TaskExecutionState, ServiceError) {
  persisted_field.required(
    status,
    fn(value) {
      task_state.from_db(
        value,
        is_ongoing,
        claimed_by,
        claimed_at,
        completed_at,
      )
    },
    "Invalid persisted task dependency status",
  )
}
