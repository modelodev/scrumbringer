//// Database operations for task types within projects.
////
//// Provides CRUD operations for task types including listing,
//// creating, updating, deleting, and verifying task type membership in projects.
////
//// Story 4.9: Added update, delete, and tasks_count support.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/service_error.{
  type ServiceError, AlreadyExists, Conflict, DbError, InvalidReference,
  NotFound, Unexpected,
}

/// A task type that categorizes tasks within a project.
/// Story 4.9 AC15: Added tasks_count field.
pub type TaskType {
  TaskType(
    id: Int,
    project_id: Int,
    name: String,
    icon: String,
    capability_id: Option(Int),
    tasks_count: Int,
  )
}

fn task_type_from_fields(
  id: Int,
  project_id: Int,
  name: String,
  icon: String,
  capability_id: Int,
  tasks_count: Int,
) -> Result(TaskType, ServiceError) {
  use parsed_capability_id <- result.try(capability_option(capability_id))
  Ok(TaskType(
    id: id,
    project_id: project_id,
    name: name,
    icon: icon,
    capability_id: parsed_capability_id,
    tasks_count: tasks_count,
  ))
}

fn task_type_from_list_row(
  row: sql.TaskTypesListRow,
) -> Result(TaskType, ServiceError) {
  task_type_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.icon,
    row.capability_id,
    row.tasks_count,
  )
}

fn task_type_from_create_row(
  row: sql.TaskTypesCreateRow,
) -> Result(TaskType, ServiceError) {
  task_type_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.icon,
    row.capability_id,
    0,
  )
}

fn task_type_from_update_row(
  row: sql.TaskTypesUpdateRow,
) -> Result(TaskType, ServiceError) {
  task_type_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.icon,
    row.capability_id,
    0,
  )
}

/// Lists all task types for a given project.
/// Story 4.9 AC15: Includes tasks_count for each type.
///
/// ## Example
///
/// ```gleam
/// list_task_types_for_project(db, project_id: 1)
/// // -> Ok([TaskType(id: 1, name: "Bug", tasks_count: 5, ...)])
/// ```
pub fn list_task_types_for_project(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(TaskType), ServiceError) {
  use returned <- result.try(
    sql.task_types_list(db, project_id)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.try_map(task_type_from_list_row)
}

/// Returns the project_id for a task type if it exists.
pub fn get_task_type_project_id(
  db: pog.Connection,
  type_id: Int,
) -> Result(Option(Int), pog.QueryError) {
  use returned <- result.try(
    pog.query("select project_id from task_types where id = $1")
    |> pog.parameter(pog.int(type_id))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db),
  )

  case returned.rows {
    [row, ..] -> Ok(Some(row))
    [] -> Ok(None)
  }
}

/// Creates a new task type in a project.
///
/// ## Example
///
/// ```gleam
/// create_task_type(db, project_id: 1, name: "Feature", icon: "star", capability_id: None)
/// // -> Ok(TaskType(...))
/// ```
pub fn create_task_type(
  db: pog.Connection,
  project_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> Result(TaskType, ServiceError) {
  let capability_param = capability_param(capability_id)

  case sql.task_types_create(db, project_id, name, icon, capability_param) {
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(persisted_field.returned_row(
        rows,
        "task_types.create_task_type",
      ))
      task_type_from_create_row(row)
    }

    Error(error) -> Error(map_create_task_type_error(error))
  }
}

fn map_create_task_type_error(error: pog.QueryError) -> ServiceError {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      map_create_task_type_constraint(error, constraint)
    _ -> DbError(error)
  }
}

fn map_create_task_type_constraint(
  error: pog.QueryError,
  constraint: String,
) -> ServiceError {
  case string.contains(constraint, "task_types") {
    True -> AlreadyExists
    False -> map_create_capability_constraint(error, constraint)
  }
}

fn map_create_capability_constraint(
  error: pog.QueryError,
  constraint: String,
) -> ServiceError {
  case string.contains(constraint, "capability") {
    True -> InvalidReference("capability_id")
    False -> DbError(error)
  }
}

/// Updates an existing task type.
/// Story 4.9 AC13: Edit task type name, icon, or capability.
///
/// ## Example
///
/// ```gleam
/// update_task_type(db, type_id: 1, name: "Bug Fix", icon: "bug-ant", capability_id: Some(2))
/// // -> Ok(TaskType(...))
/// ```
pub fn update_task_type(
  db: pog.Connection,
  type_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> Result(TaskType, ServiceError) {
  let capability_param = capability_param(capability_id)

  case sql.task_types_update(db, type_id, name, icon, capability_param) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> task_type_from_update_row(row)

    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(error) -> Error(DbError(error))
  }
}

fn capability_param(capability_id: Option(Int)) -> Int {
  case capability_id {
    None -> 0
    Some(id) -> id
  }
}

/// Deletes a task type if it has no associated tasks.
/// Story 4.9 AC14: Delete task type (only if no tasks use it).
///
/// ## Example
///
/// ```gleam
/// delete_task_type(db, type_id: 1)
/// // -> Ok(1)  // returns deleted id
/// // -> Error(DeleteHasTasks)  // if tasks exist
/// ```
pub fn delete_task_type(
  db: pog.Connection,
  type_id: Int,
) -> Result(Int, ServiceError) {
  case sql.task_types_delete(db, type_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row.id)

    Ok(pog.Returned(rows: [], ..)) -> Error(Conflict("task_type_in_use"))

    Error(error) -> Error(DbError(error))
  }
}

/// Checks if a task type belongs to a specific project.
///
/// ## Example
///
/// ```gleam
/// is_task_type_in_project(db, type_id: 1, project_id: 2)
/// // -> Ok(True)
/// ```
pub fn is_task_type_in_project(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(sql.task_types_is_in_project(
    db,
    type_id,
    project_id,
  ))

  use row <- result.try(persisted_field.query_row(returned.rows))
  Ok(row.ok)
}

fn capability_option(value: Int) -> Result(Option(Int), ServiceError) {
  case value {
    0 -> Ok(None)
    id if id > 0 -> Ok(Some(id))
    id ->
      Error(Unexpected(
        "Invalid persisted task type capability_id: " <> int.to_string(id),
      ))
  }
}
