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
import domain/project/settings as project_settings
import domain/project_role.{type ProjectRole}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
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
    healthy_pool_limit: Int,
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

pub type DepthReductionImpact {
  DepthReductionImpact(
    affected_cards_count: Int,
    available_tasks_count: Int,
    claimed_tasks_count: Int,
    affected_cards: List(DepthReductionAffectedCard),
  )
}

pub type DepthReductionAffectedCard {
  DepthReductionAffectedCard(id: Int, title: String, depth: Int)
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

pub type CreateProjectError {
  InvalidCreateProjectSettings
  CreateProjectDbError(pog.QueryError)
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
    healthy_pool_limit: 20,
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
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
) -> Result(ProjectRecord, CreateProjectError) {
  case
    project_settings.valid_project_settings(
      healthy_pool_limit,
      card_depth_names,
    )
  {
    False -> Error(InvalidCreateProjectSettings)
    True ->
      do_create_project(
        db,
        org_id,
        created_by,
        name,
        healthy_pool_limit,
        card_depth_names,
      )
  }
}

fn do_create_project(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
) -> Result(ProjectRecord, CreateProjectError) {
  pog.transaction(db, fn(tx) {
    use returned <- result.try(
      sql.projects_create(tx, org_id, name, created_by)
      |> result.map_error(CreateProjectDbError),
    )
    use row <- result.try(
      persisted_field.query_row(returned.rows)
      |> result.map_error(CreateProjectDbError),
    )
    use _ <- result.try(
      upsert_healthy_pool_limit(tx, row.id, healthy_pool_limit)
      |> result.map_error(CreateProjectDbError),
    )
    use _ <- result.try(
      replace_card_depth_names(tx, row.id, card_depth_names)
      |> result.map_error(CreateProjectDbError),
    )
    use project <- result.try(
      project_from_db_fields(
        row.id,
        row.org_id,
        row.name,
        row.created_at,
        row.my_role,
        1,
      )
      |> result.map_error(CreateProjectDbError),
    )
    Ok(
      ProjectRecord(
        ..project,
        card_depth_names: card_depth_names,
        healthy_pool_limit: healthy_pool_limit,
      ),
    )
  })
  |> result.map_error(transaction_error_to_create_project_error)
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
    with_project_settings(db, project)
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
    with_project_settings(db, project)
  })
}

fn with_project_settings(
  db: pog.Connection,
  project: ProjectRecord,
) -> Result(ProjectRecord, pog.QueryError) {
  use card_depth_names <- result.try(list_card_depth_names(db, project.id))
  use healthy_pool_limit <- result.try(healthy_pool_limit(db, project.id))
  Ok(
    ProjectRecord(
      ..project,
      card_depth_names: card_depth_names,
      healthy_pool_limit: healthy_pool_limit,
    ),
  )
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

fn healthy_pool_limit(
  db: pog.Connection,
  project_id: Int,
) -> Result(Int, pog.QueryError) {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  use returned <- result.try(
    pog.query(
      "\nselect coalesce(ps.healthy_pool_limit, 20)::int\nfrom projects p\nleft join project_settings ps on ps.project_id = p.id\nwhere p.id = $1",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [value, ..] -> Ok(value)
    [] -> Ok(20)
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
  InvalidProjectSettings
  DepthReductionBlocked(claimed_tasks_count: Int)
  UpdateProjectDbError(pog.QueryError)
}

pub type DepthReductionPreviewError {
  DepthReductionProjectNotFound
  InvalidDepthReduction
  DepthReductionDbError(pog.QueryError)
}

/// Errors returned when deleting a project.
pub type DeleteProjectError {
  DeleteProjectNotFound
  DeleteProjectDbError(pog.QueryError)
}

/// Updates a project's editable settings.
///
/// Example:
///   update_project(db, project_id, user_id, "New name", 20, project_codec.default_card_depth_names())
pub fn update_project(
  db: pog.Connection,
  project_id: Int,
  actor_user_id: Int,
  name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
) -> Result(ProjectRecord, UpdateProjectError) {
  case
    project_settings.valid_project_settings(
      healthy_pool_limit,
      card_depth_names,
    )
  {
    False -> Error(InvalidProjectSettings)
    True ->
      do_update_project(
        db,
        project_id,
        actor_user_id,
        name,
        healthy_pool_limit,
        card_depth_names,
      )
  }
}

pub fn preview_depth_reduction(
  db: pog.Connection,
  project_id: Int,
  new_max_depth: Int,
) -> Result(DepthReductionImpact, DepthReductionPreviewError) {
  case new_max_depth > 0 {
    False -> Error(InvalidDepthReduction)
    True -> do_preview_depth_reduction(db, project_id, new_max_depth)
  }
}

fn do_preview_depth_reduction(
  db: pog.Connection,
  project_id: Int,
  new_max_depth: Int,
) -> Result(DepthReductionImpact, DepthReductionPreviewError) {
  case project_exists(db, project_id) {
    Ok(False) -> Error(DepthReductionProjectNotFound)
    Error(e) -> Error(DepthReductionDbError(e))
    Ok(True) -> {
      let decoder = {
        use affected_cards_count <- decode.field(0, decode.int)
        use available_tasks_count <- decode.field(1, decode.int)
        use claimed_tasks_count <- decode.field(2, decode.int)
        decode.success(
          DepthReductionImpact(
            affected_cards_count: affected_cards_count,
            available_tasks_count: available_tasks_count,
            claimed_tasks_count: claimed_tasks_count,
            affected_cards: [],
          ),
        )
      }

      use returned <- result.try(
        pog.query(
          "\nwith recursive card_depths as (\n  select c.id, c.parent_card_id, 1::int as depth\n  from cards c\n  where c.project_id = $1\n    and c.parent_card_id is null\n  union all\n  select child.id, child.parent_card_id, parent.depth + 1\n  from cards child\n  join card_depths parent on child.parent_card_id = parent.id\n  where child.project_id = $1\n), affected_cards as (\n  select id\n  from card_depths\n  where depth > $2\n), affected_tasks as (\n  select t.id, t.execution_state\n  from tasks t\n  join affected_cards c on c.id = t.card_id\n  where t.execution_state <> 'closed'\n)\nselect\n  (select count(*)::int from affected_cards),\n  (select count(*)::int from affected_tasks where execution_state = 'available'),\n  (select count(*)::int from affected_tasks where execution_state = 'claimed')",
        )
        |> pog.parameter(pog.int(project_id))
        |> pog.parameter(pog.int(new_max_depth))
        |> pog.returning(decoder)
        |> pog.execute(db)
        |> result.map_error(DepthReductionDbError),
      )

      use affected_cards <- result.try(list_depth_reduction_affected_cards(
        db,
        project_id,
        new_max_depth,
      ))

      case returned.rows {
        [
          DepthReductionImpact(
            affected_cards_count,
            available_tasks_count,
            claimed_tasks_count,
            _,
          ),
          ..
        ] ->
          Ok(DepthReductionImpact(
            affected_cards_count,
            available_tasks_count,
            claimed_tasks_count,
            affected_cards,
          ))
        [] -> Ok(DepthReductionImpact(0, 0, 0, affected_cards))
      }
    }
  }
}

fn list_depth_reduction_affected_cards(
  db: pog.Connection,
  project_id: Int,
  new_max_depth: Int,
) -> Result(List(DepthReductionAffectedCard), DepthReductionPreviewError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use depth <- decode.field(2, decode.int)
    decode.success(DepthReductionAffectedCard(
      id: id,
      title: title,
      depth: depth,
    ))
  }

  pog.query(
    "\nwith recursive card_depths as (\n  select c.id, c.title, c.parent_card_id, 1::int as depth\n  from cards c\n  where c.project_id = $1\n    and c.parent_card_id is null\n  union all\n  select child.id, child.title, child.parent_card_id, parent.depth + 1\n  from cards child\n  join card_depths parent on child.parent_card_id = parent.id\n  where child.project_id = $1\n)\nselect id, title, depth\nfrom card_depths\nwhere depth > $2\norder by depth asc, title asc, id asc\nlimit 8",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(new_max_depth))
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) { returned.rows })
  |> result.map_error(DepthReductionDbError)
}

fn do_update_project(
  db: pog.Connection,
  project_id: Int,
  actor_user_id: Int,
  name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
) -> Result(ProjectRecord, UpdateProjectError) {
  pog.transaction(db, fn(tx) {
    use existing_depth_names <- result.try(
      list_card_depth_names(tx, project_id)
      |> result.map_error(UpdateProjectDbError),
    )

    use _ <- result.try(apply_depth_structure_change(
      tx,
      project_id,
      actor_user_id,
      existing_depth_names,
      card_depth_names,
    ))

    update_project_record(
      tx,
      project_id,
      name,
      healthy_pool_limit,
      card_depth_names,
    )
  })
  |> result.map_error(transaction_error_to_update_project_error)
}

fn apply_depth_structure_change(
  db: pog.Connection,
  project_id: Int,
  actor_user_id: Int,
  existing_depth_names: List(ProjectDepthName),
  requested_depth_names: List(ProjectDepthName),
) -> Result(Nil, UpdateProjectError) {
  let existing_depth = list.length(existing_depth_names)
  let requested_depth = list.length(requested_depth_names)

  case requested_depth < existing_depth {
    True ->
      apply_depth_reduction(db, project_id, actor_user_id, requested_depth)
    False -> Ok(Nil)
  }
}

fn apply_depth_reduction(
  db: pog.Connection,
  project_id: Int,
  actor_user_id: Int,
  new_max_depth: Int,
) -> Result(Nil, UpdateProjectError) {
  let decoder = {
    use claimed_tasks_count <- decode.field(0, decode.int)
    decode.success(claimed_tasks_count)
  }

  use returned <- result.try(
    pog.query(
      "\nwith recursive card_depths as (\n  select c.id, c.parent_card_id, c.project_id, p.org_id, 1::int as depth\n  from cards c\n  join projects p on p.id = c.project_id\n  where c.project_id = $1\n    and c.parent_card_id is null\n  union all\n  select child.id, child.parent_card_id, child.project_id, parent.org_id, parent.depth + 1\n  from cards child\n  join card_depths parent on child.parent_card_id = parent.id\n  where child.project_id = $1\n), affected_cards as (\n  select id, project_id, org_id\n  from card_depths\n  where depth > $2\n), claimed as (\n  select count(*)::int as claimed_tasks_count\n  from tasks task\n  join affected_cards card on card.id = task.card_id\n  where task.execution_state = 'claimed'\n), closed_tasks as (\n  update tasks task\n  set execution_state = 'closed',\n      closed_at = now(),\n      closed_by = $3,\n      closed_reason = 'closed_by_depth_reduction',\n      pool_lifetime_s = pool_lifetime_s + case\n        when last_entered_pool_at is null then 0\n        else greatest(0, extract(epoch from (now() - last_entered_pool_at))::bigint)\n      end,\n      last_entered_pool_at = null,\n      version = version + 1\n  where task.card_id in (select id from affected_cards)\n    and task.execution_state = 'available'\n    and (select claimed_tasks_count from claimed) = 0\n  returning task.id\n), closed_cards as (\n  update cards card\n  set execution_state = 'closed',\n      closed_at = coalesce(card.closed_at, now()),\n      closed_by = $3,\n      closed_by_kind = 'user',\n      closed_reason = 'depth_reduction'\n  from affected_cards affected\n  where card.id = affected.id\n    and card.execution_state <> 'closed'\n    and (select claimed_tasks_count from claimed) = 0\n  returning card.id, affected.project_id, affected.org_id\n), audit as (\n  insert into audit_events (\n    org_id,\n    project_id,\n    card_id,\n    actor_user_id,\n    event_type,\n    payload_json,\n    created_at\n  )\n  select\n    org_id,\n    project_id,\n    id,\n    $3,\n    'card_closed',\n    '{}'::jsonb,\n    now()\n  from closed_cards\n  returning id\n)\nselect claimed_tasks_count from claimed",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(new_max_depth))
    |> pog.parameter(pog.int(actor_user_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
    |> result.map_error(UpdateProjectDbError),
  )

  case returned.rows {
    [claimed_tasks_count, ..] if claimed_tasks_count > 0 ->
      Error(DepthReductionBlocked(claimed_tasks_count))
    _ -> pause_card_depth_rules_above(db, project_id, new_max_depth)
  }
}

fn pause_card_depth_rules_above(
  db: pog.Connection,
  project_id: Int,
  new_max_depth: Int,
) -> Result(Nil, UpdateProjectError) {
  use _updated <- result.try(
    pog.query(
      "\nupdate rules rule\nset active = false\nfrom workflows workflow\nwhere workflow.id = rule.workflow_id\n  and workflow.project_id = $1\n  and rule.resource_type = 'card'\n  and rule.card_depth > $2",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(new_max_depth))
    |> pog.execute(db)
    |> result.map_error(UpdateProjectDbError),
  )

  Ok(Nil)
}

fn transaction_error_to_update_project_error(
  error: pog.TransactionError(UpdateProjectError),
) -> UpdateProjectError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> UpdateProjectDbError(err)
  }
}

fn transaction_error_to_create_project_error(
  error: pog.TransactionError(CreateProjectError),
) -> CreateProjectError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> CreateProjectDbError(err)
  }
}

fn update_project_record(
  db: pog.Connection,
  project_id: Int,
  name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
) -> Result(ProjectRecord, UpdateProjectError) {
  case sql.project_update(db, project_id, name) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      use _ <- result.try(
        upsert_healthy_pool_limit(db, project_id, healthy_pool_limit)
        |> result.map_error(UpdateProjectDbError),
      )
      use _ <- result.try(
        replace_card_depth_names(db, project_id, card_depth_names)
        |> result.map_error(UpdateProjectDbError),
      )
      Ok(ProjectRecord(
        id: row.id,
        org_id: row.org_id,
        name: row.name,
        created_at: row.created_at,
        my_role: project_role.Manager,
        members_count: 0,
        card_depth_names: card_depth_names,
        healthy_pool_limit: healthy_pool_limit,
      ))
    }

    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateProjectNotFound)
    Error(e) -> Error(UpdateProjectDbError(e))
  }
}

fn upsert_healthy_pool_limit(
  db: pog.Connection,
  project_id: Int,
  healthy_pool_limit: Int,
) -> Result(Nil, pog.QueryError) {
  use _returned <- result.try(
    pog.query(
      "\ninsert into project_settings (project_id, healthy_pool_limit)\nvalues ($1, $2)\non conflict (project_id) do update\nset healthy_pool_limit = excluded.healthy_pool_limit",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(healthy_pool_limit))
    |> pog.execute(db),
  )
  Ok(Nil)
}

fn replace_card_depth_names(
  db: pog.Connection,
  project_id: Int,
  card_depth_names: List(ProjectDepthName),
) -> Result(Nil, pog.QueryError) {
  use _deleted <- result.try(
    pog.query("\ndelete from project_card_depth_names where project_id = $1")
    |> pog.parameter(pog.int(project_id))
    |> pog.execute(db),
  )

  card_depth_names
  |> list.try_each(fn(depth_name) {
    let ProjectDepthName(
      depth: depth,
      singular_name: singular_name,
      plural_name: plural_name,
    ) = depth_name

    use _inserted <- result.try(
      pog.query(
        "\ninsert into project_card_depth_names (project_id, depth, singular_name, plural_name)\nvalues ($1, $2, $3, $4)",
      )
      |> pog.parameter(pog.int(project_id))
      |> pog.parameter(pog.int(depth))
      |> pog.parameter(pog.text(string.trim(singular_name)))
      |> pog.parameter(pog.text(string.trim(plural_name)))
      |> pog.execute(db),
    )
    Ok(Nil)
  })
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
