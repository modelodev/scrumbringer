////
//// Task dependency persistence helpers.
////

import gleam/list
import gleam/result
import helpers/option as option_helpers
import pog

import domain/task.{type TaskDependency, TaskDependency}
import domain/task_status
import scrumbringer_server/services/service_error.{
  type ServiceError, DbError, NotFound, Unexpected,
}
import scrumbringer_server/sql

pub fn list_dependencies_for_task(
  db: pog.Connection,
  task_id: Int,
) -> Result(List(TaskDependency), ServiceError) {
  case sql.task_dependencies_list(db, task_id) {
    Ok(pog.Returned(rows: rows, ..)) ->
      rows
      |> list.map(dependency_from_list_row)
      |> Ok
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
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(dependency_from_create_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(Unexpected("empty_result"))
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

fn dependency_from_list_row(row: sql.TaskDependenciesListRow) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: row.task_id,
    title: row.title,
    status: task_status.parse_task_status(row.status)
      |> result.unwrap(task_status.Available),
    claimed_by: option_helpers.string_to_option(row.claimed_by),
  )
}

fn dependency_from_create_row(
  row: sql.TaskDependenciesCreateRow,
) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: row.task_id,
    title: row.title,
    status: task_status.parse_task_status(row.status)
      |> result.unwrap(task_status.Available),
    claimed_by: option_helpers.string_to_option(row.claimed_by),
  )
}
