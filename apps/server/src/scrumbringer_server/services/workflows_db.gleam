//// Database operations for workflows.
////
//// ## Mission
////
//// Persist workflows and their active state for projects.
////
//// ## Responsibilities
////
//// - CRUD workflows
//// - Enforce unique naming rules at persistence boundary
//// - Cascade active state updates
////
//// ## Non-responsibilities
////
//// - HTTP request handling (see `http/workflows.gleam`)
//// - Workflow execution logic (see `services/rules_engine.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for queries

import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/services/service_error.{
  type ServiceError, AlreadyExists, DbError, NotFound, Unexpected,
}
import scrumbringer_server/sql

/// Workflow record with active flag and rule count.
pub type Workflow {
  Workflow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: Option(String),
    active: Bool,
    rule_count: Int,
    created_by: Int,
    created_at: String,
  )
}

// =============================================================================
// Helpers
// =============================================================================

fn from_list_project_row(row: sql.WorkflowsListForProjectRow) -> Workflow {
  Workflow(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    active: row.active,
    rule_count: row.rule_count,
    created_by: row.created_by,
    created_at: row.created_at,
  )
}

fn from_get_row(row: sql.WorkflowsGetRow) -> Workflow {
  Workflow(
    id: row.id,
    org_id: row.org_id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    active: row.active,
    rule_count: row.rule_count,
    created_by: row.created_by,
    created_at: row.created_at,
  )
}

// =============================================================================
// Public API
// =============================================================================

/// Lists workflows for a project.
///
/// Example:
///   list_project_workflows(db, project_id)
pub fn list_project_workflows(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(Workflow), pog.QueryError) {
  use returned <- result.try(sql.workflows_list_for_project(db, project_id))

  returned.rows
  |> list.map(from_list_project_row)
  |> Ok
}

/// Fetches a workflow by id.
///
/// Example:
///   get_workflow(db, workflow_id)
pub fn get_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(Workflow, ServiceError) {
  case sql.workflows_get(db, workflow_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Creates a new workflow.
///
/// Example:
///   create_workflow(db, org_id, project_id, name, description, True, user_id)
pub fn create_workflow(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  name: String,
  description: String,
  active: Bool,
  created_by: Int,
) -> Result(Workflow, ServiceError) {
  case
    sql.workflows_create(
      db,
      org_id,
      project_id,
      name,
      description,
      active,
      created_by,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(Workflow(
        id: row.id,
        org_id: row.org_id,
        project_id: row.project_id,
        name: row.name,
        description: option_helpers.string_to_option(row.description),
        active: row.active,
        rule_count: 0,
        created_by: row.created_by,
        created_at: row.created_at,
      ))
    Ok(pog.Returned(rows: [], ..)) -> Error(Unexpected("empty_result"))
    Error(error) -> Error(map_create_workflow_error(error))
  }
}

fn map_create_workflow_error(error: pog.QueryError) -> ServiceError {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      map_create_workflow_constraint(error, constraint)
    _ -> DbError(error)
  }
}

fn map_create_workflow_constraint(
  error: pog.QueryError,
  constraint: String,
) -> ServiceError {
  case string.contains(constraint, "workflows") {
    True -> AlreadyExists
    False -> DbError(error)
  }
}

/// Updates workflow metadata (name/description/active).
///
/// Example:
///   update_workflow(db, workflow_id, org_id, project_id, name, desc, 1)
pub fn update_workflow(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
  name: Option(String),
  description: Option(String),
) -> Result(Workflow, ServiceError) {
  case
    sql.workflows_update(
      db,
      workflow_id,
      org_id,
      project_id,
      option_helpers.option_to_value(name, "__unset__"),
      option_helpers.option_to_value(description, "__unset__"),
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(Workflow(
        id: row.id,
        org_id: row.org_id,
        project_id: row.project_id,
        name: row.name,
        description: option_helpers.string_to_option(row.description),
        active: row.active,
        rule_count: 0,
        created_by: row.created_by,
        created_at: row.created_at,
      ))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(error) -> Error(map_update_workflow_error(error))
  }
}

fn map_update_workflow_error(error: pog.QueryError) -> ServiceError {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      map_update_workflow_constraint(error, constraint)
    _ -> DbError(error)
  }
}

fn map_update_workflow_constraint(
  error: pog.QueryError,
  constraint: String,
) -> ServiceError {
  case string.contains(constraint, "workflows") {
    True -> AlreadyExists
    False -> DbError(error)
  }
}

/// Deletes a workflow.
///
/// Example:
///   delete_workflow(db, workflow_id, org_id, project_id)
pub fn delete_workflow(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
) -> Result(Nil, ServiceError) {
  case sql.workflows_delete(db, workflow_id, org_id, project_id) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Sets a workflow active flag and cascades to related rules.
///
/// Example:
///   set_active_cascade(db, workflow_id, org_id, project_id, True)
pub fn set_active_cascade(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
  active: Bool,
) -> Result(Nil, ServiceError) {
  case sql.workflows_set_active(db, workflow_id, org_id, project_id, active) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> {
      let _ = sql.rules_set_active_for_workflow(db, workflow_id, active)
      Ok(Nil)
    }
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}
