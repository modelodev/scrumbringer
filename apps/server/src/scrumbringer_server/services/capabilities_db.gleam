//// Database operations for project capabilities (skills).
////
//// Capabilities represent skills or competencies that can be assigned to
//// project members and required for tasks within a project.

import gleam/list
import gleam/result
import gleam/string
import pog
import scrumbringer_server/services/persisted_field
import scrumbringer_server/sql

/// A capability (skill) defined within a project.
pub type Capability {
  Capability(id: Int, project_id: Int, name: String, created_at: String)
}

/// A user's capability within a specific project.
pub type ProjectMemberCapability {
  ProjectMemberCapability(
    project_id: Int,
    user_id: Int,
    capability_id: Int,
    capability_name: String,
  )
}

/// Errors that can occur when creating a capability.
pub type CreateCapabilityError {
  AlreadyExists
  DbError(pog.QueryError)
}

fn capability_from_fields(
  id: Int,
  project_id: Int,
  name: String,
  created_at: String,
) -> Capability {
  Capability(id: id, project_id: project_id, name: name, created_at: created_at)
}

fn capability_from_list_row(
  row: sql.CapabilitiesListForProjectRow,
) -> Capability {
  capability_from_fields(row.id, row.project_id, row.name, row.created_at)
}

fn capability_from_create_row(row: sql.CapabilitiesCreateRow) -> Capability {
  capability_from_fields(row.id, row.project_id, row.name, row.created_at)
}

fn member_capability_from_fields(
  project_id: Int,
  user_id: Int,
  capability_id: Int,
  capability_name: String,
) -> ProjectMemberCapability {
  ProjectMemberCapability(
    project_id: project_id,
    user_id: user_id,
    capability_id: capability_id,
    capability_name: capability_name,
  )
}

fn member_capability_from_row(
  row: sql.ProjectMemberCapabilitiesListRow,
) -> ProjectMemberCapability {
  member_capability_from_fields(
    row.project_id,
    row.user_id,
    row.capability_id,
    row.capability_name,
  )
}

fn capability_member_from_fields(
  project_id: Int,
  capability_id: Int,
  user_id: Int,
) -> CapabilityMember {
  CapabilityMember(
    project_id: project_id,
    capability_id: capability_id,
    user_id: user_id,
  )
}

fn capability_member_from_row(
  row: sql.CapabilityMembersListRow,
) -> CapabilityMember {
  capability_member_from_fields(row.project_id, row.capability_id, row.user_id)
}

/// Lists all capabilities defined for a project.
pub fn list_capabilities_for_project(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(Capability), pog.QueryError) {
  use returned <- result.try(sql.capabilities_list_for_project(db, project_id))

  returned.rows
  |> list.map(capability_from_list_row)
  |> Ok
}

/// Creates a new capability for a project.
///
/// Returns `AlreadyExists` if a capability with the same name already exists.
pub fn create_capability(
  db: pog.Connection,
  project_id: Int,
  name: String,
) -> Result(Capability, CreateCapabilityError) {
  case sql.capabilities_create(db, project_id, name) {
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(
        persisted_field.query_row(rows)
        |> result.map_error(DbError),
      )
      Ok(capability_from_create_row(row))
    }

    Error(error) -> map_create_error(error)
  }
}

fn map_create_error(
  error: pog.QueryError,
) -> Result(Capability, CreateCapabilityError) {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      // Justification: nested case inspects constraint name for uniqueness errors.
      case string.contains(constraint, "capabilities") {
        True -> Error(AlreadyExists)
        False -> Error(DbError(error))
      }
    _ -> Error(DbError(error))
  }
}

/// Deletes a capability from a project.
pub fn delete_capability(
  db: pog.Connection,
  project_id: Int,
  capability_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(sql.capabilities_delete(
    db,
    capability_id,
    project_id,
  ))
  Ok(returned.count > 0)
}

/// Checks if a capability belongs to a project.
pub fn capability_is_in_project(
  db: pog.Connection,
  capability_id: Int,
  project_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(sql.capabilities_is_in_project(
    db,
    capability_id,
    project_id,
  ))
  use row <- result.try(persisted_field.query_row(returned.rows))
  Ok(row.ok)
}

/// Lists all capabilities for a project member.
pub fn list_member_capabilities(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(List(ProjectMemberCapability), pog.QueryError) {
  use returned <- result.try(sql.project_member_capabilities_list(
    db,
    project_id,
    user_id,
  ))

  returned.rows
  |> list.map(member_capability_from_row)
  |> Ok
}

/// Adds a capability to a project member.
pub fn add_member_capability(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  capability_id: Int,
) -> Result(Nil, pog.QueryError) {
  use _ <- result.try(sql.project_member_capabilities_insert(
    db,
    project_id,
    user_id,
    capability_id,
  ))
  Ok(Nil)
}

/// Removes a capability from a project member.
pub fn remove_member_capability(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  capability_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(sql.project_member_capabilities_delete(
    db,
    project_id,
    user_id,
    capability_id,
  ))
  Ok(returned.count > 0)
}

/// Removes all capabilities from a project member.
pub fn remove_all_member_capabilities(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, pog.QueryError) {
  use _ <- result.try(sql.project_member_capabilities_delete_all(
    db,
    project_id,
    user_id,
  ))
  Ok(Nil)
}

// =============================================================================
// Capability Members (Story 4.7 AC20-21) - Reverse direction
// =============================================================================

/// A user ID that has a specific capability.
pub type CapabilityMember {
  CapabilityMember(project_id: Int, capability_id: Int, user_id: Int)
}

/// Lists all members who have a specific capability.
pub fn list_capability_members(
  db: pog.Connection,
  project_id: Int,
  capability_id: Int,
) -> Result(List(CapabilityMember), pog.QueryError) {
  use returned <- result.try(sql.capability_members_list(
    db,
    project_id,
    capability_id,
  ))

  returned.rows
  |> list.map(capability_member_from_row)
  |> Ok
}

/// Removes all members from a capability.
pub fn remove_all_capability_members(
  db: pog.Connection,
  project_id: Int,
  capability_id: Int,
) -> Result(Nil, pog.QueryError) {
  use _ <- result.try(sql.capability_members_delete_all(
    db,
    project_id,
    capability_id,
  ))
  Ok(Nil)
}
