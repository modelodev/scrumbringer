//// Database operations for workflows.
////
//// ## Mission
////
//// Persist workflows and their active state for projects.
////
//// ## Responsibilities
////
//// - CRUD workflows
//// - Enforce unique naming rules at repository boundary
//// - Cascade active state updates
////
//// ## Non-responsibilities
////
//// - HTTP request handling (see `http/workflows.gleam`)
//// - Workflow execution logic (see `use_case/rules_engine.gleam`)
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
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/service_error.{
  type ServiceError, AlreadyExists, DbError, NotFound, Unexpected,
}

const unchanged_text_value = "__unset__"

/// Persisted workflow record with active flag and rule count.
pub type WorkflowRecord {
  WorkflowRecord(
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

fn text_update_value(value: Option(String)) -> String {
  option_helpers.option_to_value(value, unchanged_text_value)
}

fn workflow_from_fields(
  id: Int,
  org_id: Int,
  project_id: Int,
  name: String,
  description: String,
  active: Bool,
  rule_count: Int,
  created_by: Int,
  created_at: String,
) -> WorkflowRecord {
  WorkflowRecord(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: option_helpers.string_to_option(description),
    active: active,
    rule_count: rule_count,
    created_by: created_by,
    created_at: created_at,
  )
}

fn from_list_project_row(row: sql.WorkflowsListForProjectRow) -> WorkflowRecord {
  workflow_from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.active,
    row.rule_count,
    row.created_by,
    row.created_at,
  )
}

fn from_get_row(row: sql.WorkflowsGetRow) -> WorkflowRecord {
  workflow_from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.active,
    row.rule_count,
    row.created_by,
    row.created_at,
  )
}

fn from_create_row(row: sql.WorkflowsCreateRow) -> WorkflowRecord {
  workflow_from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.active,
    0,
    row.created_by,
    row.created_at,
  )
}

fn from_update_row(row: sql.WorkflowsUpdateRow) -> WorkflowRecord {
  workflow_from_fields(
    row.id,
    row.org_id,
    row.project_id,
    row.name,
    row.description,
    row.active,
    0,
    row.created_by,
    row.created_at,
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
) -> Result(List(WorkflowRecord), pog.QueryError) {
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
) -> Result(WorkflowRecord, ServiceError) {
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
) -> Result(WorkflowRecord, ServiceError) {
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
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(persisted_field.returned_row(
        rows,
        "workflows.create_workflow",
      ))
      Ok(from_create_row(row))
    }
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
) -> Result(WorkflowRecord, ServiceError) {
  case
    sql.workflows_update(
      db,
      workflow_id,
      org_id,
      project_id,
      text_update_value(name),
      text_update_value(description),
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_update_row(row))
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
    Ok(pog.Returned(
      rows: [
        sql.WorkflowsDeleteRow(
          workflow_found: False,
          has_executions: _,
          paused_id: _,
          deleted_id: _,
        ),
        ..
      ],
      ..,
    )) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..))
      if row.paused_id > 0 || row.deleted_id > 0
    -> Ok(Nil)
    Ok(pog.Returned(rows: [_row, ..], ..)) ->
      Error(Unexpected("delete_workflow returned no paused or deleted row"))
    Ok(pog.Returned(rows: [], ..)) ->
      Error(Unexpected("delete_workflow returned no decision row"))
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
