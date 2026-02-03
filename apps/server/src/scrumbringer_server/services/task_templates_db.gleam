//// Database operations for task templates.
////
//// ## Mission
////
//// Persist reusable task templates scoped to projects.
////
//// ## Responsibilities
////
//// - List, create, update, and delete templates
//// - Map SQL rows into domain records
////
//// ## Non-responsibilities
////
//// - HTTP request handling (see `http/task_templates.gleam`)
//// - Task type validation rules (see `services/task_types_db.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for query execution

import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/services/service_error.{
  type ServiceError, DbError, InvalidReference, NotFound,
}
import scrumbringer_server/sql

/// Template definition for creating tasks (includes rules_count).
pub type TaskTemplate {
  TaskTemplate(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: Option(String),
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
    rules_count: Int,
  )
}

// =============================================================================
// Helpers
// =============================================================================

/// Story 4.9 AC20: Includes rules_count from SQL.
fn from_list_project_row(
  row: sql.TaskTemplatesListForProjectRow,
) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
    rules_count: row.rules_count,
  )
}

fn from_get_row(row: sql.TaskTemplatesGetRow) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
    rules_count: 0,
  )
}

fn from_create_row(row: sql.TaskTemplatesCreateRow) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
    rules_count: 0,
  )
}

fn from_update_row(row: sql.TaskTemplatesUpdateRow) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
    rules_count: 0,
  )
}

// =============================================================================
// Public API
// =============================================================================

/// Lists templates for a project.
///
/// Example:
///   list_project_templates(db, project_id)
pub fn list_project_templates(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(TaskTemplate), pog.QueryError) {
  use returned <- result.try(sql.task_templates_list_for_project(db, project_id))

  returned.rows
  |> list.map(from_list_project_row)
  |> Ok
}

/// Fetches a template by id.
///
/// Example:
///   get_template(db, template_id)
pub fn get_template(
  db: pog.Connection,
  template_id: Int,
) -> Result(TaskTemplate, ServiceError) {
  case sql.task_templates_get(db, template_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Creates a new task template.
///
/// Example:
///   create_template(db, org_id, project_id, name, desc, type_id, priority, user_id)
pub fn create_template(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  created_by: Int,
) -> Result(TaskTemplate, ServiceError) {
  case
    sql.task_templates_create(
      db,
      org_id,
      project_id,
      type_id,
      name,
      description,
      priority,
      created_by,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_create_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(InvalidReference("type_id"))
    Error(e) -> Error(DbError(e))
  }
}

/// Updates a task template.
///
/// Example:
///   update_template(db, template_id, org_id, project_id, name, desc, type_id, priority)
pub fn update_template(
  db: pog.Connection,
  template_id: Int,
  org_id: Int,
  project_id: Int,
  name: Option(String),
  description: Option(String),
  type_id: Option(Int),
  priority: Option(Int),
) -> Result(TaskTemplate, ServiceError) {
  case
    sql.task_templates_update(
      db,
      template_id,
      project_id,
      org_id,
      option_helpers.option_to_value(name, "__unset__"),
      option_helpers.option_to_value(description, "__unset__"),
      option_helpers.option_to_value(type_id, 0),
      option_helpers.option_to_value(priority, 0),
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_update_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Deletes a template by id.
///
/// Example:
///   delete_template(db, template_id, org_id)
pub fn delete_template(
  db: pog.Connection,
  template_id: Int,
  org_id: Int,
) -> Result(Nil, ServiceError) {
  case sql.task_templates_delete(db, template_id, org_id) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

// Justification: nested case improves clarity for branching logic.
/// Maps constraint violations into domain errors.
///
/// Example:
///   constraint_to_error(error)
pub fn constraint_to_error(error: pog.QueryError) -> Result(Nil, ServiceError) {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      case string.contains(constraint, "task_templates") {
        True -> Error(InvalidReference("type_id"))
        False -> Error(DbError(error))
      }

    _ -> Error(DbError(error))
  }
}
