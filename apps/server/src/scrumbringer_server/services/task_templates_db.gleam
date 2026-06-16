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

const unchanged_text_update_value = "__unset__"

const unchanged_positive_int_update_value = 0

// =============================================================================
// Helpers
// =============================================================================

fn text_update_value(value: Option(String)) -> String {
  option_helpers.option_to_value(value, unchanged_text_update_value)
}

fn type_id_update_value(value: Option(Int)) -> Int {
  option_helpers.option_to_value(value, unchanged_positive_int_update_value)
}

fn priority_update_value(value: Option(Int)) -> Int {
  option_helpers.option_to_value(value, unchanged_positive_int_update_value)
}

/// Story 4.9 AC20: Includes rules_count from SQL.
fn from_list_project_row(
  row: sql.TaskTemplatesListForProjectRow,
) -> Result(TaskTemplate, ServiceError) {
  from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.type_id,
    row.type_name,
    row.priority,
    row.created_by,
    row.created_at,
    row.rules_count,
  )
}

fn from_get_row(
  row: sql.TaskTemplatesGetRow,
) -> Result(TaskTemplate, ServiceError) {
  from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.type_id,
    row.type_name,
    row.priority,
    row.created_by,
    row.created_at,
    0,
  )
}

fn from_create_row(
  row: sql.TaskTemplatesCreateRow,
) -> Result(TaskTemplate, ServiceError) {
  from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.type_id,
    row.type_name,
    row.priority,
    row.created_by,
    row.created_at,
    0,
  )
}

fn from_update_row(
  row: sql.TaskTemplatesUpdateRow,
) -> Result(TaskTemplate, ServiceError) {
  from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.type_id,
    row.type_name,
    row.priority,
    row.created_by,
    row.created_at,
    0,
  )
}

fn from_fields(
  id: Int,
  org_id: Int,
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  type_name: String,
  priority: Int,
  created_by: Int,
  created_at: String,
  rules_count: Int,
) -> Result(TaskTemplate, ServiceError) {
  Ok(TaskTemplate(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: option_helpers.string_to_option(description),
    type_id: type_id,
    type_name: type_name,
    priority: priority,
    created_by: created_by,
    created_at: created_at,
    rules_count: rules_count,
  ))
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
) -> Result(List(TaskTemplate), ServiceError) {
  use returned <- result.try(
    sql.task_templates_list_for_project(db, project_id)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.try_map(from_list_project_row)
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
    Ok(pog.Returned(rows: [row, ..], ..)) -> from_get_row(row)
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
    Ok(pog.Returned(rows: [row, ..], ..)) -> from_create_row(row)
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
      text_update_value(name),
      text_update_value(description),
      type_id_update_value(type_id),
      priority_update_value(priority),
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> from_update_row(row)
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
