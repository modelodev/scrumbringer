//// Database operations for task templates.
////
//// Handles listing and CRUD for reusable task templates scoped to projects.

import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql

/// Story 4.9 AC20: Added rules_count field.
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

pub type CreateTemplateError {
  CreateInvalidTypeId
  CreateDbError(pog.QueryError)
}

pub type UpdateTemplateError {
  UpdateNotFound
  UpdateInvalidTypeId
  UpdateDbError(pog.QueryError)
}

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

pub fn list_project_templates(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(TaskTemplate), pog.QueryError) {
  use returned <- result.try(sql.task_templates_list_for_project(db, project_id))

  returned.rows
  |> list.map(from_list_project_row)
  |> Ok
}

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

pub fn update_template(
  db: pog.Connection,
  template_id: Int,
  org_id: Int,
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
) -> Result(TaskTemplate, UpdateTemplateError) {
  case
    sql.task_templates_update(
      db,
      template_id,
      project_id,
      org_id,
      name,
      description,
      type_id,
      priority,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_update_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateNotFound)
    Error(e) -> Error(UpdateDbError(e))
  }
}

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
