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
