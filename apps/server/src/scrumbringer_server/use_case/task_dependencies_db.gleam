////
//// Task dependency repository helpers.
////

import gleam/list
import gleam/result
import helpers/option as option_helpers
import pog

import domain/task.{type TaskDependency, TaskDependency}
import domain/task_status
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
  dependency_from_fields(row.task_id, row.title, row.status, row.claimed_by)
}

fn dependency_from_create_row(
  row: sql.TaskDependenciesCreateRow,
) -> Result(TaskDependency, ServiceError) {
  dependency_from_fields(row.task_id, row.title, row.status, row.claimed_by)
}

fn dependency_from_fields(
  task_id: Int,
  title: String,
  status_value: String,
  claimed_by: String,
) -> Result(TaskDependency, ServiceError) {
  use status <- result.try(parse_dependency_status(status_value))
  Ok(TaskDependency(
    depends_on_task_id: task_id,
    title: title,
    status: status,
    claimed_by: option_helpers.string_to_option(claimed_by),
  ))
}

fn parse_dependency_status(
  value: String,
) -> Result(task_status.TaskPhase, ServiceError) {
  persisted_field.required(
    value,
    task_status.parse_task_status,
    "Invalid persisted task dependency status",
  )
}
