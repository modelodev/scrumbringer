//// Database operations for task types within projects.
////
//// Provides CRUD operations for task types including listing,
//// creating, and verifying task type membership in projects.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/sql

/// A task type that categorizes tasks within a project.
pub type TaskType {
  TaskType(
    id: Int,
    project_id: Int,
    name: String,
    icon: String,
    capability_id: Option(Int),
  )
}

/// Errors that can occur when creating a task type.
pub type CreateTaskTypeError {
  AlreadyExists
  InvalidCapabilityId
  DbError(pog.QueryError)
  NoRowReturned
}

/// Lists all task types for a given project.
///
/// ## Example
///
/// ```gleam
/// list_task_types_for_project(db, project_id: 1)
/// // -> Ok([TaskType(id: 1, name: "Bug", ...)])
/// ```
pub fn list_task_types_for_project(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(TaskType), pog.QueryError) {
  use returned <- result.try(sql.task_types_list(db, project_id))

  returned.rows
  |> list.map(fn(row) {
    TaskType(
      id: row.id,
      project_id: row.project_id,
      name: row.name,
      icon: row.icon,
      capability_id: capability_option(row.capability_id),
    )
  })
  |> Ok
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
) -> Result(TaskType, CreateTaskTypeError) {
  let capability_param = case capability_id {
    None -> 0
    Some(id) -> id
  }

  case sql.task_types_create(db, project_id, name, icon, capability_param) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(TaskType(
        id: row.id,
        project_id: row.project_id,
        name: row.name,
        icon: row.icon,
        capability_id: capability_option(row.capability_id),
      ))

    Ok(pog.Returned(rows: [], ..)) -> Error(NoRowReturned)

    Error(error) ->
      case error {
        pog.ConstraintViolated(constraint: constraint, ..) ->
          case string.contains(constraint, "task_types") {
            True -> Error(AlreadyExists)
            False ->
              case string.contains(constraint, "capability") {
                True -> Error(InvalidCapabilityId)
                False -> Error(DbError(error))
              }
          }

        _ -> Error(DbError(error))
      }
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

  case returned.rows {
    [row, ..] -> Ok(row.ok)
    [] -> Ok(False)
  }
}

fn capability_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    id -> Some(id)
  }
}
