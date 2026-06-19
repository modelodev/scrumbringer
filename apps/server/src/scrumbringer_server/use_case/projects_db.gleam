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
//// - Business rules beyond repository (see `use_case/authorization.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for query execution
//// - Shares `ProjectRole` with domain types

import domain/project.{type ProjectDepthName, ProjectDepthName}
import domain/project/project_codec
import domain/project_role.{type ProjectRole}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/persisted_role

/// Internal project repository record with user-specific role and member count.
pub type ProjectRecord {
  ProjectRecord(
    id: Int,
    org_id: Int,
    name: String,
    created_at: String,
    my_role: ProjectRole,
    members_count: Int,
    card_depth_names: List(ProjectDepthName),
  )
}

/// Internal project membership repository record for a user.
pub type ProjectMemberRecord {
  ProjectMemberRecord(
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
  DbError(pog.QueryError)
}

fn project_from_fields(
  id: Int,
  org_id: Int,
  name: String,
  created_at: String,
  my_role: ProjectRole,
  members_count: Int,
) -> ProjectRecord {
  ProjectRecord(
    id: id,
    org_id: org_id,
    name: name,
    created_at: created_at,
    my_role: my_role,
    members_count: members_count,
    card_depth_names: project_codec.default_card_depth_names(),
  )
}

fn project_from_db_fields(
  id: Int,
  org_id: Int,
  name: String,
  created_at: String,
  my_role: String,
  members_count: Int,
) -> Result(ProjectRecord, pog.QueryError) {
  use parsed_role <- result.try(persisted_role.project_role(my_role))
  Ok(project_from_fields(
    id,
    org_id,
    name,
    created_at,
    parsed_role,
    members_count,
  ))
}

fn project_member_from_fields(
  project_id: Int,
  user_id: Int,
  role: ProjectRole,
  created_at: String,
  claimed_count: Int,
) -> ProjectMemberRecord {
  ProjectMemberRecord(
    project_id: project_id,
    user_id: user_id,
    role: role,
    created_at: created_at,
    claimed_count: claimed_count,
  )
}

fn project_member_from_db_fields(
  project_id: Int,
  user_id: Int,
  role: String,
  created_at: String,
  claimed_count: Int,
) -> Result(ProjectMemberRecord, pog.QueryError) {
  use parsed_role <- result.try(persisted_role.project_role(role))
  Ok(project_member_from_fields(
    project_id,
    user_id,
    parsed_role,
    created_at,
    claimed_count,
  ))
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
) -> Result(ProjectRecord, pog.QueryError) {
  use returned <- result.try(sql.projects_create(db, org_id, name, created_by))

  use row <- result.try(persisted_field.query_row(returned.rows))
  project_from_db_fields(
    row.id,
    row.org_id,
    row.name,
    row.created_at,
    row.my_role,
    1,
  )
}

/// Lists projects that the user can access.
///
/// Example:
///   list_projects_for_user(db, user_id)
pub fn list_projects_for_user(
  db: pog.Connection,
  user_id: Int,
) -> Result(List(ProjectRecord), pog.QueryError) {
  use returned <- result.try(sql.projects_for_user(db, user_id))

  returned.rows
  |> list.try_map(fn(row) {
    use project <- result.try(project_from_db_fields(
      row.id,
      row.org_id,
      row.name,
      row.created_at,
      row.my_role,
      row.members_count,
    ))
    with_card_depth_names(db, project)
  })
}

pub fn list_projects_for_org(
  db: pog.Connection,
  org_id: Int,
) -> Result(List(ProjectRecord), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    use my_role <- decode.field(4, decode.string)
    use members_count <- decode.field(5, decode.int)
    decode.success(#(id, org_id, name, created_at, my_role, members_count))
  }

  use returned <- result.try(
    pog.query(
      "\nselect\n  p.id,\n  p.org_id,\n  p.name,\n  to_char(p.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,\n  'manager' as my_role,\n  (select count(*) from project_members where project_id = p.id) as members_count\nfrom projects p\nwhere p.org_id = $1\norder by p.name asc",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  returned.rows
  |> list.try_map(fn(row) {
    let #(id, org_id, name, created_at, my_role, members_count) = row
    use project <- result.try(project_from_db_fields(
      id,
      org_id,
      name,
      created_at,
      my_role,
      members_count,
    ))
    with_card_depth_names(db, project)
  })
}

fn with_card_depth_names(
  db: pog.Connection,
  project: ProjectRecord,
) -> Result(ProjectRecord, pog.QueryError) {
  use card_depth_names <- result.try(list_card_depth_names(db, project.id))
  Ok(ProjectRecord(..project, card_depth_names: card_depth_names))
}

fn list_card_depth_names(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(ProjectDepthName), pog.QueryError) {
  let decoder = {
    use depth <- decode.field(0, decode.int)
    use singular_name <- decode.field(1, decode.string)
    use plural_name <- decode.field(2, decode.string)
    decode.success(ProjectDepthName(
      depth: depth,
      singular_name: singular_name,
      plural_name: plural_name,
    ))
  }

  use returned <- result.try(
    pog.query(
      "\nselect depth, singular_name, plural_name\nfrom project_card_depth_names\nwhere project_id = $1\norder by depth asc",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(project_codec.default_card_depth_names())
    rows -> Ok(rows)
  }
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

  use row <- result.try(persisted_field.query_row(returned.rows))
  case row.is_manager {
    True -> Ok(True)
    False -> has_active_api_token_project_grant(db, project_id, user_id)
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

  use row <- result.try(persisted_field.query_row(returned.rows))
  case row.is_member {
    True -> Ok(True)
    False -> has_active_api_token_project_grant(db, project_id, user_id)
  }
}

fn has_active_api_token_project_grant(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use has_grant <- decode.field(0, decode.bool)
    decode.success(has_grant)
  }

  use returned <- result.try(
    pog.query(
      "\nselect exists(\n  select 1\n  from api_tokens t\n  join projects p on p.id = $1 and p.org_id = t.org_id\n  join users u on u.id = t.integration_user_id\n  where t.integration_user_id = $2\n    and u.user_kind = 'integration'\n    and u.deleted_at is null\n    and t.revoked_at is null\n    and (t.expires_at is null or t.expires_at > now())\n    and (t.project_id is null or t.project_id = $1)\n) as has_grant",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  persisted_field.query_row(returned.rows)
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

  use row <- result.try(persisted_field.query_row(returned.rows))
  Ok(row.is_manager)
}

/// Lists all members for a project.
///
/// Example:
///   list_members(db, project_id)
pub fn list_members(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(ProjectMemberRecord), pog.QueryError) {
  use returned <- result.try(sql.project_members_list(db, project_id))

  returned.rows
  |> list.try_map(fn(row) {
    project_member_from_db_fields(
      row.project_id,
      row.user_id,
      row.role,
      row.created_at,
      row.claimed_count,
    )
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
) -> Result(ProjectMemberRecord, AddMemberError) {
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

fn insert_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: ProjectRole,
) -> Result(ProjectMemberRecord, AddMemberError) {
  let role_value = project_role.to_string(role)
  case sql.project_members_insert(db, project_id, user_id, role_value) {
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(
        persisted_field.query_row(rows)
        |> result.map_error(DbError),
      )
      project_member_from_db_fields(
        row.project_id,
        row.user_id,
        row.role,
        row.created_at,
        0,
      )
      |> result.map_error(DbError)
    }

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
  UpdateDbError(pog.QueryError)
}

type ProjectRoleUpdateStatus {
  ProjectRoleUpdateAllowed
  ProjectRoleUpdateNoChange
  ProjectRoleUpdateLastManager
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
  use status <- result.try(parse_role_update_status(row.status))

  case status {
    ProjectRoleUpdateLastManager -> Error(UpdateLastManager)
    ProjectRoleUpdateAllowed | ProjectRoleUpdateNoChange ->
      parse_role_update_result(row)
  }
}

fn parse_role_update_status(
  value: String,
) -> Result(ProjectRoleUpdateStatus, UpdateMemberRoleError) {
  case value {
    "last_manager" -> Ok(ProjectRoleUpdateLastManager)
    "allowed" -> Ok(ProjectRoleUpdateAllowed)
    "no_change" -> Ok(ProjectRoleUpdateNoChange)
    _ ->
      Error(
        UpdateDbError(pog.PostgresqlError(
          code: "UNEXPECTED_STATUS",
          name: "unexpected_status",
          message: "Unexpected status: " <> value,
        )),
      )
  }
}

fn parse_role_update_result(
  row: sql.ProjectMembersUpdateRoleRow,
) -> Result(UpdateMemberRoleResult, UpdateMemberRoleError) {
  use role <- result.try(
    persisted_role.project_role(row.role)
    |> result.map_error(UpdateDbError),
  )
  use previous_role <- result.try(
    persisted_role.project_role(row.previous_role)
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
) -> Result(ProjectRecord, UpdateProjectError) {
  case sql.project_update(db, project_id, name) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(project_from_fields(
        row.id,
        row.org_id,
        row.name,
        row.created_at,
        project_role.Manager,
        0,
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
