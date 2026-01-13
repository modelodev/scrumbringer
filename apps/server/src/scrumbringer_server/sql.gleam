//// This module contains the code to run the sql queries defined in
//// `./src/scrumbringer_server/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog

/// A row you get from running the `capabilities_create` query
/// defined in `./src/scrumbringer_server/sql/capabilities_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CapabilitiesCreateRow {
  CapabilitiesCreateRow(id: Int, org_id: Int, name: String, created_at: String)
}

/// name: create_capability
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn capabilities_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(CapabilitiesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(CapabilitiesCreateRow(id:, org_id:, name:, created_at:))
  }

  "-- name: create_capability
insert into capabilities (org_id, name)
values ($1, $2)
returning
  id,
  org_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `capabilities_is_in_org` query
/// defined in `./src/scrumbringer_server/sql/capabilities_is_in_org.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CapabilitiesIsInOrgRow {
  CapabilitiesIsInOrgRow(ok: Bool)
}

/// name: capability_is_in_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn capabilities_is_in_org(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(CapabilitiesIsInOrgRow), pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.bool)
    decode.success(CapabilitiesIsInOrgRow(ok:))
  }

  "-- name: capability_is_in_org
select exists(
  select 1
  from capabilities
  where id = $1
    and org_id = $2
) as ok;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `capabilities_list` query
/// defined in `./src/scrumbringer_server/sql/capabilities_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CapabilitiesListRow {
  CapabilitiesListRow(id: Int, org_id: Int, name: String, created_at: String)
}

/// name: list_capabilities_for_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn capabilities_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(CapabilitiesListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(CapabilitiesListRow(id:, org_id:, name:, created_at:))
  }

  "-- name: list_capabilities_for_org
select
  id,
  org_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from capabilities
where org_id = $1
order by name asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invites` query
/// defined in `./src/scrumbringer_server/sql/org_invites.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitesRow {
  OrgInvitesRow(code: String, created_at: String, expires_at: String)
}

/// name: create_org_invite
/// Insert a new org invite and return the API-facing fields.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invites(
  db: pog.Connection,
  arg_1: String,
  arg_2: Int,
  arg_3: Int,
  arg_4: Int,
) -> Result(pog.Returned(OrgInvitesRow), pog.QueryError) {
  let decoder = {
    use code <- decode.field(0, decode.string)
    use created_at <- decode.field(1, decode.string)
    use expires_at <- decode.field(2, decode.string)
    decode.success(OrgInvitesRow(code:, created_at:, expires_at:))
  }

  "-- name: create_org_invite
-- Insert a new org invite and return the API-facing fields.
insert into org_invites (code, org_id, created_by, expires_at)
values ($1, $2, $3, now() + (($4::int) * interval '1 hour'))
returning
  code,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  to_char(expires_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as expires_at;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `ping` query
/// defined in `./src/scrumbringer_server/sql/ping.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PingRow {
  PingRow(ok: Int)
}

/// Simple query used to verify Squirrel generation
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn ping(
  db: pog.Connection,
) -> Result(pog.Returned(PingRow), pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.int)
    decode.success(PingRow(ok:))
  }

  "-- Simple query used to verify Squirrel generation
select 1 as ok;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_insert` query
/// defined in `./src/scrumbringer_server/sql/project_members_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersInsertRow {
  ProjectMembersInsertRow(
    project_id: Int,
    user_id: Int,
    role: String,
    created_at: String,
  )
}

/// name: insert_project_member
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_insert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
) -> Result(pog.Returned(ProjectMembersInsertRow), pog.QueryError) {
  let decoder = {
    use project_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(ProjectMembersInsertRow(
      project_id:,
      user_id:,
      role:,
      created_at:,
    ))
  }

  "-- name: insert_project_member
insert into project_members (project_id, user_id, role)
values ($1, $2, $3)
returning
  project_id,
  user_id,
  role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_is_admin` query
/// defined in `./src/scrumbringer_server/sql/project_members_is_admin.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersIsAdminRow {
  ProjectMembersIsAdminRow(is_admin: Bool)
}

/// name: is_project_admin
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_is_admin(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersIsAdminRow), pog.QueryError) {
  let decoder = {
    use is_admin <- decode.field(0, decode.bool)
    decode.success(ProjectMembersIsAdminRow(is_admin:))
  }

  "-- name: is_project_admin
select exists(
  select 1
  from project_members
  where project_id = $1
    and user_id = $2
    and role = 'admin'
) as is_admin;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_list` query
/// defined in `./src/scrumbringer_server/sql/project_members_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersListRow {
  ProjectMembersListRow(
    project_id: Int,
    user_id: Int,
    role: String,
    created_at: String,
  )
}

/// name: list_project_members
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ProjectMembersListRow), pog.QueryError) {
  let decoder = {
    use project_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(ProjectMembersListRow(
      project_id:,
      user_id:,
      role:,
      created_at:,
    ))
  }

  "-- name: list_project_members
select
  project_id,
  user_id,
  role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from project_members
where project_id = $1
order by user_id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_remove` query
/// defined in `./src/scrumbringer_server/sql/project_members_remove.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersRemoveRow {
  ProjectMembersRemoveRow(target_role: String, admin_count: Int, removed: Bool)
}

/// name: remove_project_member
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_remove(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersRemoveRow), pog.QueryError) {
  let decoder = {
    use target_role <- decode.field(0, decode.string)
    use admin_count <- decode.field(1, decode.int)
    use removed <- decode.field(2, decode.bool)
    decode.success(ProjectMembersRemoveRow(target_role:, admin_count:, removed:))
  }

  "-- name: remove_project_member
with
  target as (
    select role
    from project_members
    where project_id = $1
      and user_id = $2
  ), admin_count as (
    select count(*)::int as count
    from project_members
    where project_id = $1
      and role = 'admin'
  ), deleted as (
    delete from project_members
    where project_id = $1
      and user_id = $2
      and not (
        (select role from target) = 'admin'
        and (select count from admin_count) = 1
      )
    returning 1 as ok
  )
select
  coalesce((select role from target), '') as target_role,
  (select count from admin_count) as admin_count,
  exists(select 1 from deleted) as removed;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `projects_create` query
/// defined in `./src/scrumbringer_server/sql/projects_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectsCreateRow {
  ProjectsCreateRow(
    id: Int,
    org_id: Int,
    name: String,
    created_at: String,
    my_role: String,
  )
}

/// name: create_project
/// Create a project and add the creator as an admin member.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn projects_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(ProjectsCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    use my_role <- decode.field(4, decode.string)
    decode.success(ProjectsCreateRow(id:, org_id:, name:, created_at:, my_role:))
  }

  "-- name: create_project
-- Create a project and add the creator as an admin member.
with new_project as (
  insert into projects (org_id, name)
  values ($1, $2)
  returning id, org_id, name, created_at
), membership as (
  insert into project_members (project_id, user_id, role)
  select new_project.id, $3, 'admin'
  from new_project
)
select
  new_project.id,
  new_project.org_id,
  new_project.name,
  to_char(new_project.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  'admin' as my_role
from new_project;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `projects_for_user` query
/// defined in `./src/scrumbringer_server/sql/projects_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectsForUserRow {
  ProjectsForUserRow(
    id: Int,
    org_id: Int,
    name: String,
    created_at: String,
    my_role: String,
  )
}

/// name: list_projects_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn projects_for_user(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ProjectsForUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    use my_role <- decode.field(4, decode.string)
    decode.success(ProjectsForUserRow(
      id:,
      org_id:,
      name:,
      created_at:,
      my_role:,
    ))
  }

  "-- name: list_projects_for_user
select
  p.id,
  p.org_id,
  p.name,
  to_char(p.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  pm.role as my_role
from projects p
join project_members pm on pm.project_id = p.id
where pm.user_id = $1
order by p.name asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `projects_org_id` query
/// defined in `./src/scrumbringer_server/sql/projects_org_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectsOrgIdRow {
  ProjectsOrgIdRow(org_id: Int)
}

/// name: project_org_id
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn projects_org_id(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ProjectsOrgIdRow), pog.QueryError) {
  let decoder = {
    use org_id <- decode.field(0, decode.int)
    decode.success(ProjectsOrgIdRow(org_id:))
  }

  "-- name: project_org_id
select org_id
from projects
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_capabilities_delete_all` query
/// defined in `./src/scrumbringer_server/sql/user_capabilities_delete_all.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserCapabilitiesDeleteAllRow {
  UserCapabilitiesDeleteAllRow(user_id: Int)
}

/// name: delete_user_capabilities_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_capabilities_delete_all(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(UserCapabilitiesDeleteAllRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.int)
    decode.success(UserCapabilitiesDeleteAllRow(user_id:))
  }

  "-- name: delete_user_capabilities_for_user
delete from user_capabilities
where user_id = $1
returning user_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_capabilities_insert` query
/// defined in `./src/scrumbringer_server/sql/user_capabilities_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserCapabilitiesInsertRow {
  UserCapabilitiesInsertRow(user_id: Int, capability_id: Int)
}

/// name: insert_user_capability
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_capabilities_insert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(UserCapabilitiesInsertRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.int)
    use capability_id <- decode.field(1, decode.int)
    decode.success(UserCapabilitiesInsertRow(user_id:, capability_id:))
  }

  "-- name: insert_user_capability
insert into user_capabilities (user_id, capability_id)
values ($1, $2)
returning user_id, capability_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_capabilities_list` query
/// defined in `./src/scrumbringer_server/sql/user_capabilities_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserCapabilitiesListRow {
  UserCapabilitiesListRow(capability_id: Int)
}

/// name: list_user_capability_ids
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_capabilities_list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(UserCapabilitiesListRow), pog.QueryError) {
  let decoder = {
    use capability_id <- decode.field(0, decode.int)
    decode.success(UserCapabilitiesListRow(capability_id:))
  }

  "-- name: list_user_capability_ids
select
  uc.capability_id
from user_capabilities uc
join capabilities c on c.id = uc.capability_id
where uc.user_id = $1
  and c.org_id = $2
order by uc.capability_id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `users_org_id` query
/// defined in `./src/scrumbringer_server/sql/users_org_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UsersOrgIdRow {
  UsersOrgIdRow(org_id: Int)
}

/// name: user_org_id
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn users_org_id(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(UsersOrgIdRow), pog.QueryError) {
  let decoder = {
    use org_id <- decode.field(0, decode.int)
    decode.success(UsersOrgIdRow(org_id:))
  }

  "-- name: user_org_id
select org_id
from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
