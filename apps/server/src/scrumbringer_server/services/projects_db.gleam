//// Database operations for projects and project membership.
////
//// ## Mission
////
//// Provides data access layer for projects within organizations.
////
//// ## Responsibilities
////
//// - List projects accessible to a user
//// - Manage project members and roles
//// - Handle project creation and updates

import gleam/list
import gleam/result
import pog
import scrumbringer_server/sql

pub type Project {
  Project(
    id: Int,
    org_id: Int,
    name: String,
    created_at: String,
    my_role: String,
    members_count: Int,
  )
}

pub type ProjectMember {
  ProjectMember(project_id: Int, user_id: Int, role: String, created_at: String)
}

pub type RemoveMemberError {
  MembershipNotFound
  CannotRemoveLastManager
  RemoveDbError(pog.QueryError)
}

pub type AddMemberError {
  ProjectNotFound
  TargetUserNotFound
  TargetUserWrongOrg
  AlreadyMember
  InvalidRole
  DbError(pog.QueryError)
}

pub fn create_project(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  name: String,
) -> Result(Project, pog.QueryError) {
  use returned <- result.try(sql.projects_create(db, org_id, name, created_by))

  case returned.rows {
    [row, ..] ->
      Ok(Project(
        id: row.id,
        org_id: row.org_id,
        name: row.name,
        created_at: row.created_at,
        my_role: row.my_role,
        members_count: 1,  // Creator is the first member
      ))

    [] ->
      Error(pog.PostgresqlError(
        code: "NO_ROWS",
        name: "no_rows",
        message: "No rows returned",
      ))
  }
}

pub fn list_projects_for_user(
  db: pog.Connection,
  user_id: Int,
) -> Result(List(Project), pog.QueryError) {
  use returned <- result.try(sql.projects_for_user(db, user_id))

  returned.rows
  |> list.map(fn(row) {
    Project(
      id: row.id,
      org_id: row.org_id,
      name: row.name,
      created_at: row.created_at,
      my_role: row.my_role,
      members_count: row.members_count,
    )
  })
  |> Ok
}

pub fn is_project_manager(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(sql.project_members_is_manager(
    db,
    project_id,
    user_id,
  ))

  case returned.rows {
    [row, ..] -> Ok(row.is_manager)
    [] -> Ok(False)
  }
}

pub fn is_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(sql.project_members_is_member(
    db,
    project_id,
    user_id,
  ))

  case returned.rows {
    [row, ..] -> Ok(row.is_member)
    [] -> Ok(False)
  }
}

pub fn is_any_project_manager_in_org(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(sql.project_members_is_any_manager_in_org(
    db,
    user_id,
    org_id,
  ))

  case returned.rows {
    [row, ..] -> Ok(row.is_manager)
    [] -> Ok(False)
  }
}

pub fn list_members(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(ProjectMember), pog.QueryError) {
  use returned <- result.try(sql.project_members_list(db, project_id))

  returned.rows
  |> list.map(fn(row) {
    ProjectMember(
      project_id: row.project_id,
      user_id: row.user_id,
      role: row.role,
      created_at: row.created_at,
    )
  })
  |> Ok
}

pub fn add_member(
  db: pog.Connection,
  project_id: Int,
  target_user_id: Int,
  role: String,
) -> Result(ProjectMember, AddMemberError) {
  use _ <- result.try(validate_role(role))

  use project_org_id <- result.try(
    fetch_project_org_id(db, project_id)
    |> result.map_error(fn(e) { e }),
  )

  use target_org_id <- result.try(
    fetch_user_org_id(db, target_user_id)
    |> result.map_error(fn(e) { e }),
  )

  case project_org_id == target_org_id {
    False -> Error(TargetUserWrongOrg)
    True -> insert_member(db, project_id, target_user_id, role)
  }
}

fn validate_role(role: String) -> Result(Nil, AddMemberError) {
  case role {
    "manager" | "member" -> Ok(Nil)
    _ -> Error(InvalidRole)
  }
}

fn fetch_project_org_id(
  db: pog.Connection,
  project_id: Int,
) -> Result(Int, AddMemberError) {
  case sql.projects_org_id(db, project_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row.org_id)
    Ok(pog.Returned(rows: [], ..)) -> Error(ProjectNotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn fetch_user_org_id(
  db: pog.Connection,
  user_id: Int,
) -> Result(Int, AddMemberError) {
  case sql.users_org_id(db, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row.org_id)
    Ok(pog.Returned(rows: [], ..)) -> Error(TargetUserNotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn insert_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: String,
) -> Result(ProjectMember, AddMemberError) {
  case sql.project_members_insert(db, project_id, user_id, role) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(ProjectMember(
        project_id: row.project_id,
        user_id: row.user_id,
        role: row.role,
        created_at: row.created_at,
      ))

    Ok(pog.Returned(rows: [], ..)) ->
      Error(
        DbError(pog.PostgresqlError(
          code: "NO_ROWS",
          name: "no_rows",
          message: "No rows returned",
        )),
      )

    Error(e) ->
      case e {
        pog.ConstraintViolated(constraint: _, ..) -> Error(AlreadyMember)
        _ -> Error(DbError(e))
      }
  }
}

pub fn remove_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, RemoveMemberError) {
  case sql.project_members_remove(db, project_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      case row.target_role {
        "" -> Error(MembershipNotFound)
        "manager" if row.manager_count == 1 && row.removed == False ->
          Error(CannotRemoveLastManager)
        _ ->
          case row.removed {
            True -> Ok(Nil)
            False -> Error(MembershipNotFound)
          }
      }
    }

    Ok(pog.Returned(rows: [], ..)) -> Error(MembershipNotFound)
    Error(e) -> Error(RemoveDbError(e))
  }
}

// =============================================================================
// Role Update
// =============================================================================

pub type UpdateMemberRoleResult {
  RoleUpdated(user_id: Int, email: String, role: String, previous_role: String)
}

pub type UpdateMemberRoleError {
  UpdateMemberNotFound
  UpdateLastManager
  UpdateInvalidRole
  UpdateDbError(pog.QueryError)
}

pub fn update_member_role(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  new_role: String,
) -> Result(UpdateMemberRoleResult, UpdateMemberRoleError) {
  // Validate role value first
  case new_role {
    "manager" | "member" ->
      do_update_member_role(db, project_id, user_id, new_role)
    _ -> Error(UpdateInvalidRole)
  }
}

fn do_update_member_role(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  new_role: String,
) -> Result(UpdateMemberRoleResult, UpdateMemberRoleError) {
  case sql.project_members_update_role(db, project_id, user_id, new_role) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      case row.status {
        "last_manager" -> Error(UpdateLastManager)
        "allowed" | "no_change" ->
          Ok(RoleUpdated(
            user_id: row.user_id,
            email: row.email,
            role: row.role,
            previous_role: row.previous_role,
          ))
        _ ->
          Error(UpdateDbError(pog.PostgresqlError(
            code: "UNEXPECTED_STATUS",
            name: "unexpected_status",
            message: "Unexpected status: " <> row.status,
          )))
      }
    }

    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateMemberNotFound)
    Error(e) -> Error(UpdateDbError(e))
  }
}

// =============================================================================
// Project Update/Delete (Story 4.8 AC39)
// =============================================================================

pub type UpdateProjectError {
  UpdateProjectNotFound
  UpdateProjectDbError(pog.QueryError)
}

pub type DeleteProjectError {
  DeleteProjectNotFound
  DeleteProjectDbError(pog.QueryError)
}

/// Update a project's name.
pub fn update_project(
  db: pog.Connection,
  project_id: Int,
  name: String,
) -> Result(Project, UpdateProjectError) {
  case sql.project_update(db, project_id, name) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(Project(
        id: row.id,
        org_id: row.org_id,
        name: row.name,
        created_at: row.created_at,
        my_role: "manager",  // Only managers can update
        members_count: 0,  // Not returned by update query
      ))

    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateProjectNotFound)
    Error(e) -> Error(UpdateProjectDbError(e))
  }
}

/// Delete a project and all related data.
pub fn delete_project(
  db: pog.Connection,
  project_id: Int,
) -> Result(Int, DeleteProjectError) {
  case sql.project_delete(db, project_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row.id)
    Ok(pog.Returned(rows: [], ..)) -> Error(DeleteProjectNotFound)
    Error(e) -> Error(DeleteProjectDbError(e))
  }
}
