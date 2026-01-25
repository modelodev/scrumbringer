////
//// Database operations for workflows.
////
//// Provides CRUD operations for workflows, including active cascade.
//// Note: Workflows are now project-scoped only (no org-scoped workflows).

import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql

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

pub type CreateWorkflowError {
  CreateWorkflowAlreadyExists
  CreateWorkflowDbError(pog.QueryError)
}

pub type UpdateWorkflowError {
  UpdateWorkflowNotFound
  UpdateWorkflowAlreadyExists
  UpdateWorkflowDbError(pog.QueryError)
}

pub type DeleteWorkflowError {
  DeleteWorkflowNotFound
  DeleteWorkflowDbError(pog.QueryError)
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

pub fn list_project_workflows(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(Workflow), pog.QueryError) {
  use returned <- result.try(sql.workflows_list_for_project(db, project_id))

  returned.rows
  |> list.map(from_list_project_row)
  |> Ok
}

pub fn get_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(Workflow, UpdateWorkflowError) {
  case sql.workflows_get(db, workflow_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateWorkflowNotFound)
    Error(e) -> Error(UpdateWorkflowDbError(e))
  }
}

pub fn create_workflow(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  name: String,
  description: String,
  active: Bool,
  created_by: Int,
) -> Result(Workflow, CreateWorkflowError) {
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
    Ok(pog.Returned(rows: [], ..)) ->
      Error(CreateWorkflowDbError(pog.UnexpectedArgumentCount(7, 0)))
    Error(error) ->
      case error {
        pog.ConstraintViolated(constraint: constraint, ..) ->
          case string.contains(constraint, "workflows") {
            True -> Error(CreateWorkflowAlreadyExists)
            False -> Error(CreateWorkflowDbError(error))
          }

        _ -> Error(CreateWorkflowDbError(error))
      }
  }
}

pub fn update_workflow(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
  name: Option(String),
  description: Option(String),
) -> Result(Workflow, UpdateWorkflowError) {
  case
    sql.workflows_update(db, workflow_id, org_id, project_id, name, description)
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
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateWorkflowNotFound)
    Error(error) ->
      case error {
        pog.ConstraintViolated(constraint: constraint, ..) ->
          case string.contains(constraint, "workflows") {
            True -> Error(UpdateWorkflowAlreadyExists)
            False -> Error(UpdateWorkflowDbError(error))
          }

        _ -> Error(UpdateWorkflowDbError(error))
      }
  }
}

pub fn delete_workflow(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
) -> Result(Nil, DeleteWorkflowError) {
  case sql.workflows_delete(db, workflow_id, org_id, project_id) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(DeleteWorkflowNotFound)
    Error(e) -> Error(DeleteWorkflowDbError(e))
  }
}

pub fn set_active_cascade(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
  active: Bool,
) -> Result(Nil, UpdateWorkflowError) {
  case sql.workflows_set_active(db, workflow_id, org_id, project_id, active) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> {
      let _ = sql.rules_set_active_for_workflow(db, workflow_id, active)
      Ok(Nil)
    }
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateWorkflowNotFound)
    Error(e) -> Error(UpdateWorkflowDbError(e))
  }
}
