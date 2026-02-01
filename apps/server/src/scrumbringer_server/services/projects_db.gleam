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
////
//// ## Non-responsibilities
////
//// - HTTP request handling (see `http/projects.gleam`)
//// - Business rules beyond persistence (see `services/authorization.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for query execution
//// - Shares `ProjectRole` with domain types

import domain/project_role.{type ProjectRole}
import gleam/list
import gleam/result
import pog
import scrumbringer_server/sql

/// Project with user-specific role and member count.
pub type Project {
  Project(
    id: Int,
    org_id: Int,
    name: String,
    created_at: String,
    my_role: ProjectRole,
    members_count: Int,
  )
}

/// Project membership record for a user.
pub type ProjectMember {
  ProjectMember(
    project_id: Int,
    user_id: Int,
    role: ProjectRole,
    created_at: String,
    claimed_count: Int,
  )
}

/// Errors returned when removing a project member.
pub type RemoveMemberError {
  MembershipNotFound
  CannotRemoveLastManager
  RemoveDbError(pog.QueryError)
}

/// Errors returned when adding a project member.
pub type AddMemberError {
  ProjectNotFound
  TargetUserNotFound
  TargetUserWrongOrg
  AlreadyMember
  InvalidRole
  DbError(pog.QueryError)
}

fn parse_project_role(value: String) -> Result(ProjectRole, pog.QueryError) {
  case project_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) ->
      Error(pog.PostgresqlError(
        code: "INVALID_ROLE",
        name: "invalid_role",
        message: "Invalid project role: " <> value,
      ))
  }
}

/// Creates a new project and adds the creator as manager.
///
/// Example:
///   create_project(db, org_id, user_id, "Project Alpha")
pub fn create_project(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  name: String,
) -> Result(Project, pog.QueryError) {
  use returned <- result.try(sql.projects_create(db, org_id, name, created_by))

  case returned.rows {
    [row, ..] -> {
      use my_role <- result.try(parse_project_role(row.my_role))
      Ok(Project(
        id: row.id,
        org_id: row.org_id,
        name: row.name,
        created_at: row.created_at,
        my_role: my_role,
        members_count: 1,
        // Creator is the first member
      ))
    }

    [] ->
      Error(pog.PostgresqlError(
        code: "NO_ROWS",
        name: "no_rows",
        message: "No rows returned",
      ))
  }
}

/// Lists projects that the user can access.
///
/// Example:
///   list_projects_for_user(db, user_id)
pub fn list_projects_for_user(
  db: pog.Connection,
  user_id: Int,
) -> Result(List(Project), pog.QueryError) {
  use returned <- result.try(sql.projects_for_user(db, user_id))

  returned.rows
  |> list.try_map(fn(row) {
    use my_role <- result.try(parse_project_role(row.my_role))
    Ok(Project(
      id: row.id,
      org_id: row.org_id,
      name: row.name,
      created_at: row.created_at,
      my_role: my_role,
      members_count: row.members_count,
    ))
  })
}

/// Checks whether a user is a manager of a project.
///
/// Example:
///   is_project_manager(db, project_id, user_id)
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

/// Checks whether a user is a member of a project.
///
/// Example:
///   is_project_member(db, project_id, user_id)
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

/// Checks whether a project exists.
///
/// Example:
///   project_exists(db, project_id)
pub fn project_exists(
  db: pog.Connection,
  project_id: Int,
) -> Result(Bool, pog.QueryError) {
  case sql.projects_org_id(db, project_id) {
    Ok(pog.Returned(rows: [_row, ..], ..)) -> Ok(True)
    Ok(pog.Returned(rows: [], ..)) -> Ok(False)
    Error(e) -> Error(e)
  }
}

/// Checks whether a user exists.
///
/// Example:
///   user_exists(db, user_id)
pub fn user_exists(
  db: pog.Connection,
  user_id: Int,
) -> Result(Bool, pog.QueryError) {
  case sql.users_org_id(db, user_id) {
    Ok(pog.Returned(rows: [_row, ..], ..)) -> Ok(True)
    Ok(pog.Returned(rows: [], ..)) -> Ok(False)
    Error(e) -> Error(e)
  }
}

/// Checks whether the user is a manager of any project in the org.
///
/// Example:
///   is_any_project_manager_in_org(db, user_id, org_id)
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

/// Lists all members for a project.
///
/// Example:
///   list_members(db, project_id)
pub fn list_members(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(ProjectMember), pog.QueryError) {
  use returned <- result.try(sql.project_members_list(db, project_id))

  returned.rows
  |> list.try_map(fn(row) {
    use role <- result.try(parse_project_role(row.role))
    Ok(ProjectMember(
      project_id: row.project_id,
      user_id: row.user_id,
      role: role,
      created_at: row.created_at,
      claimed_count: row.claimed_count,
    ))
  })
}

/// Adds a user to a project with the provided role.
///
/// Example:
///   add_member(db, project_id, user_id, project_role.Manager)
pub fn add_member(
  db: pog.Connection,
  project_id: Int,
  target_user_id: Int,
  role: ProjectRole,
) -> Result(ProjectMember, AddMemberError) {
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

// Justification: nested case improves clarity for branching logic.
fn insert_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: ProjectRole,
) -> Result(ProjectMember, AddMemberError) {
  let role_value = project_role.to_string(role)
  case sql.project_members_insert(db, project_id, user_id, role_value) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      // Justification: nested case validates role mapping from database row.
      case parse_project_role(row.role) {
        Ok(parsed_role) ->
          Ok(ProjectMember(
            project_id: row.project_id,
            user_id: row.user_id,
            role: parsed_role,
            created_at: row.created_at,
            claimed_count: 0,
          ))
        Error(e) -> Error(DbError(e))
      }

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

/// Removes a user from a project if rules allow it.
///
/// Example:
///   remove_member(db, project_id, user_id)
pub fn remove_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, RemoveMemberError) {
  case sql.project_members_remove(db, project_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> interpret_remove_row(row)

    Ok(pog.Returned(rows: [], ..)) -> Error(MembershipNotFound)
    Error(e) -> Error(RemoveDbError(e))
  }
}

fn interpret_remove_row(
  row: sql.ProjectMembersRemoveRow,
) -> Result(Nil, RemoveMemberError) {
  let manager_role = project_role.to_string(project_role.Manager)

  case True {
    _ if row.target_role == "" -> Error(MembershipNotFound)
    _
      if row.target_role == manager_role
      && row.manager_count == 1
      && row.removed == False
    -> Error(CannotRemoveLastManager)
    _ if row.removed -> Ok(Nil)
    _ -> Error(MembershipNotFound)
  }
}

// =============================================================================
// Role Update
// =============================================================================

/// Result returned after updating a member role.
pub type UpdateMemberRoleResult {
  RoleUpdated(
    user_id: Int,
    email: String,
    role: ProjectRole,
    previous_role: ProjectRole,
  )
}

/// Errors returned when updating a project member role.
pub type UpdateMemberRoleError {
  UpdateMemberNotFound
  UpdateLastManager
  UpdateInvalidRole
  UpdateDbError(pog.QueryError)
}

/// Updates a member role within a project.
///
/// Example:
///   update_member_role(db, project_id, user_id, project_role.Manager)
pub fn update_member_role(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  new_role: ProjectRole,
) -> Result(UpdateMemberRoleResult, UpdateMemberRoleError) {
  do_update_member_role(db, project_id, user_id, new_role)
}

fn do_update_member_role(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  new_role: ProjectRole,
) -> Result(UpdateMemberRoleResult, UpdateMemberRoleError) {
  let new_role_value = project_role.to_string(new_role)
  case
    sql.project_members_update_role(db, project_id, user_id, new_role_value)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> parse_update_role_row(row)
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateMemberNotFound)
    Error(e) -> Error(UpdateDbError(e))
  }
}

fn parse_update_role_row(
  row: sql.ProjectMembersUpdateRoleRow,
) -> Result(UpdateMemberRoleResult, UpdateMemberRoleError) {
  case row.status {
    "last_manager" -> Error(UpdateLastManager)
    "allowed" | "no_change" -> parse_role_update_result(row)
    _ ->
      Error(
        UpdateDbError(pog.PostgresqlError(
          code: "UNEXPECTED_STATUS",
          name: "unexpected_status",
          message: "Unexpected status: " <> row.status,
        )),
      )
  }
}

fn parse_role_update_result(
  row: sql.ProjectMembersUpdateRoleRow,
) -> Result(UpdateMemberRoleResult, UpdateMemberRoleError) {
  use role <- result.try(
    parse_project_role(row.role)
    |> result.map_error(UpdateDbError),
  )
  use previous_role <- result.try(
    parse_project_role(row.previous_role)
    |> result.map_error(UpdateDbError),
  )

  Ok(RoleUpdated(
    user_id: row.user_id,
    email: row.email,
    role: role,
    previous_role: previous_role,
  ))
}

// =============================================================================
// Project Update/Delete (Story 4.8 AC39)
// =============================================================================

/// Errors returned when updating a project.
pub type UpdateProjectError {
  UpdateProjectNotFound
  UpdateProjectDbError(pog.QueryError)
}

/// Errors returned when deleting a project.
pub type DeleteProjectError {
  DeleteProjectNotFound
  DeleteProjectDbError(pog.QueryError)
}

/// Updates a project's name.
///
/// Example:
///   update_project(db, project_id, "New name")
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
        my_role: project_role.Manager,
        // Only managers can update
        members_count: 0,
        // Not returned by update query
      ))

    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateProjectNotFound)
    Error(e) -> Error(UpdateProjectDbError(e))
  }
}

/// Deletes a project and all related data.
///
/// Example:
///   delete_project(db, project_id)
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
