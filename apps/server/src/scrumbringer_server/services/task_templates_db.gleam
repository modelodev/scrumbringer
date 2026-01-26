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
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
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

/// Errors returned when creating a template.
pub type CreateTemplateError {
  CreateInvalidTypeId
  CreateDbError(pog.QueryError)
}

/// Errors returned when updating a template.
pub type UpdateTemplateError {
  UpdateNotFound
  UpdateInvalidTypeId
  UpdateDbError(pog.QueryError)
}

/// Errors returned when deleting a template.
pub type DeleteTemplateError {
  DeleteNotFound
  DeleteDbError(pog.QueryError)
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
) -> Result(TaskTemplate, UpdateTemplateError) {
  case sql.task_templates_get(db, template_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateNotFound)
    Error(e) -> Error(UpdateDbError(e))
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
) -> Result(TaskTemplate, CreateTemplateError) {
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
    Ok(pog.Returned(rows: [], ..)) -> Error(CreateInvalidTypeId)
    Error(e) -> Error(CreateDbError(e))
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
) -> Result(TaskTemplate, UpdateTemplateError) {
  case
    sql.task_templates_update(
      db,
      template_id,
      project_id,
      org_id,
      option_string_update_to_db(name),
      option_string_update_to_db(description),
      option_int_to_db(type_id),
      option_int_to_db(priority),
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_update_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateNotFound)
    Error(e) -> Error(UpdateDbError(e))
  }
}

fn option_int_to_db(value: Option(Int)) -> Int {
  case value {
    None -> 0
    Some(actual) -> actual
  }
}

fn option_string_update_to_db(value: Option(String)) -> String {
  case value {
    None -> "__unset__"
    Some(actual) -> actual
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
) -> Result(Nil, DeleteTemplateError) {
  case sql.task_templates_delete(db, template_id, org_id) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(DeleteNotFound)
    Error(e) -> Error(DeleteDbError(e))
  }
}

// Justification: nested case improves clarity for branching logic.
/// Maps constraint violations into domain errors.
///
/// Example:
///   constraint_to_error(error)
pub fn constraint_to_error(
  error: pog.QueryError,
) -> Result(Nil, CreateTemplateError) {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      case string.contains(constraint, "task_templates") {
        True -> Error(CreateInvalidTypeId)
        False -> Error(CreateDbError(error))
      }

    _ -> Error(CreateDbError(error))
  }
}
