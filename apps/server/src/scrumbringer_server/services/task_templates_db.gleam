//// Database operations for task templates.
////
//// Handles listing and CRUD for reusable task templates scoped to org or project.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/sql

pub type TaskTemplate {
  TaskTemplate(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: Option(String),
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
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

fn option_to_param(value: Option(Int)) -> Int {
  case value {
    None -> 0
    Some(id) -> id
  }
}

fn int_to_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    id -> Some(id)
  }
}

fn string_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    text -> Some(text)
  }
}

fn from_list_org_row(row: sql.TaskTemplatesListForOrgRow) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: int_to_option(row.project_id),
    name: row.name,
    description: string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
  )
}

fn from_list_project_row(
  row: sql.TaskTemplatesListForProjectRow,
) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: int_to_option(row.project_id),
    name: row.name,
    description: string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
  )
}

fn from_get_row(row: sql.TaskTemplatesGetRow) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: int_to_option(row.project_id),
    name: row.name,
    description: string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
  )
}

fn from_create_row(row: sql.TaskTemplatesCreateRow) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
  )
}

fn from_update_row(row: sql.TaskTemplatesUpdateRow) -> TaskTemplate {
  TaskTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
  )
}

// =============================================================================
// Public API
// =============================================================================

pub fn list_org_templates(
  db: pog.Connection,
  org_id: Int,
) -> Result(List(TaskTemplate), pog.QueryError) {
  use returned <- result.try(sql.task_templates_list_for_org(db, org_id))

  returned.rows
  |> list.map(from_list_org_row)
  |> Ok
}

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
  project_id: Option(Int),
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  created_by: Int,
) -> Result(TaskTemplate, CreateTemplateError) {
  let project_param = option_to_param(project_id)

  case
    sql.task_templates_create(
      db,
      org_id,
      project_param,
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
  project_id: Option(Int),
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
) -> Result(TaskTemplate, UpdateTemplateError) {
  let project_param = option_to_param(project_id)

  case
    sql.task_templates_update(
      db,
      template_id,
      project_param,
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
