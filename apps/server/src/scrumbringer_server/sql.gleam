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

/// A row you get from running the `org_invite_links_list` query
/// defined in `./src/scrumbringer_server/sql/org_invite_links_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInviteLinksListRow {
  OrgInviteLinksListRow(
    email: String,
    token: String,
    created_at: String,
    used_at: String,
    invalidated_at: String,
    state: String,
  )
}

/// name: list_org_invite_links
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invite_links_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(OrgInviteLinksListRow), pog.QueryError) {
  let decoder = {
    use email <- decode.field(0, decode.string)
    use token <- decode.field(1, decode.string)
    use created_at <- decode.field(2, decode.string)
    use used_at <- decode.field(3, decode.string)
    use invalidated_at <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    decode.success(OrgInviteLinksListRow(
      email:,
      token:,
      created_at:,
      used_at:,
      invalidated_at:,
      state:,
    ))
  }

  "-- name: list_org_invite_links
select
  email,
  token,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  coalesce(to_char(used_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as used_at,
  coalesce(to_char(invalidated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as invalidated_at,
  case
    when used_at is not null then 'used'
    when invalidated_at is not null then 'invalidated'
    else 'active'
  end as state
from org_invite_links
where org_id = $1
order by email asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invite_links_upsert` query
/// defined in `./src/scrumbringer_server/sql/org_invite_links_upsert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInviteLinksUpsertRow {
  OrgInviteLinksUpsertRow(
    email: String,
    token: String,
    created_at: String,
    used_at: String,
    invalidated_at: String,
    state: String,
  )
}

/// name: upsert_org_invite_link
/// Invalidate any active invite link for email and create a new one.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invite_links_upsert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: Int,
) -> Result(pog.Returned(OrgInviteLinksUpsertRow), pog.QueryError) {
  let decoder = {
    use email <- decode.field(0, decode.string)
    use token <- decode.field(1, decode.string)
    use created_at <- decode.field(2, decode.string)
    use used_at <- decode.field(3, decode.string)
    use invalidated_at <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    decode.success(OrgInviteLinksUpsertRow(
      email:,
      token:,
      created_at:,
      used_at:,
      invalidated_at:,
      state:,
    ))
  }

  "-- name: upsert_org_invite_link
-- Invalidate any active invite link for email and create a new one.
with invalidated as (
  update org_invite_links
  set invalidated_at = now()
  where org_id = $1
    and email = $2
    and used_at is null
    and invalidated_at is null
  returning 1
),
inserted as (
  insert into org_invite_links (org_id, email, token, created_by)
  values ($1, $2, $3, $4)
  returning email, token, created_at, used_at, invalidated_at
)
select
  email,
  token,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  coalesce(to_char(used_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as used_at,
  coalesce(to_char(invalidated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as invalidated_at,
  case
    when used_at is not null then 'used'
    when invalidated_at is not null then 'invalidated'
    else 'active'
  end as state
from inserted
where (select count(*) from invalidated) >= 0;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
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

/// A row you get from running the `org_users_list` query
/// defined in `./src/scrumbringer_server/sql/org_users_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgUsersListRow {
  OrgUsersListRow(id: Int, email: String, org_role: String, created_at: String)
}

/// name: list_org_users
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_users_list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(OrgUsersListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use org_role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(OrgUsersListRow(id:, email:, org_role:, created_at:))
  }

  "-- name: list_org_users
select
  id,
  email,
  org_role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from users
where org_id = $1
  and ($2 = '' or email ilike ('%' || $2 || '%'))
order by email asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
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

/// A row you get from running the `project_members_is_any_admin_in_org` query
/// defined in `./src/scrumbringer_server/sql/project_members_is_any_admin_in_org.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersIsAnyAdminInOrgRow {
  ProjectMembersIsAnyAdminInOrgRow(is_admin: Bool)
}

/// name: is_any_project_admin_in_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_is_any_admin_in_org(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersIsAnyAdminInOrgRow), pog.QueryError) {
  let decoder = {
    use is_admin <- decode.field(0, decode.bool)
    decode.success(ProjectMembersIsAnyAdminInOrgRow(is_admin:))
  }

  "-- name: is_any_project_admin_in_org
select exists(
  select 1
  from project_members pm
  join projects p on p.id = pm.project_id
  where pm.user_id = $1
    and pm.role = 'admin'
    and p.org_id = $2
) as is_admin;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_is_member` query
/// defined in `./src/scrumbringer_server/sql/project_members_is_member.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersIsMemberRow {
  ProjectMembersIsMemberRow(is_member: Bool)
}

/// name: is_project_member
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_is_member(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersIsMemberRow), pog.QueryError) {
  let decoder = {
    use is_member <- decode.field(0, decode.bool)
    decode.success(ProjectMembersIsMemberRow(is_member:))
  }

  "-- name: is_project_member
select exists(
  select 1
  from project_members
  where project_id = $1
    and user_id = $2
) as is_member;
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

/// A row you get from running the `task_notes_create` query
/// defined in `./src/scrumbringer_server/sql/task_notes_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskNotesCreateRow {
  TaskNotesCreateRow(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
}

/// name: task_notes_create
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_notes_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
) -> Result(pog.Returned(TaskNotesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use task_id <- decode.field(1, decode.int)
    use user_id <- decode.field(2, decode.int)
    use content <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    decode.success(TaskNotesCreateRow(
      id:,
      task_id:,
      user_id:,
      content:,
      created_at:,
    ))
  }

  "-- name: task_notes_create
insert into task_notes (task_id, user_id, content)
values ($1, $2, $3)
returning
  id,
  task_id,
  user_id,
  content,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_notes_list` query
/// defined in `./src/scrumbringer_server/sql/task_notes_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskNotesListRow {
  TaskNotesListRow(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
}

/// name: task_notes_list
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_notes_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(TaskNotesListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use task_id <- decode.field(1, decode.int)
    use user_id <- decode.field(2, decode.int)
    use content <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    decode.success(TaskNotesListRow(
      id:,
      task_id:,
      user_id:,
      content:,
      created_at:,
    ))
  }

  "-- name: task_notes_list
select
  n.id,
  n.task_id,
  n.user_id,
  n.content,
  to_char(n.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from task_notes n
where n.task_id = $1
order by n.created_at asc, n.id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_positions_list_for_user` query
/// defined in `./src/scrumbringer_server/sql/task_positions_list_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskPositionsListForUserRow {
  TaskPositionsListForUserRow(
    task_id: Int,
    user_id: Int,
    x: Int,
    y: Int,
    updated_at: String,
  )
}

/// name: task_positions_list_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_positions_list_for_user(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(TaskPositionsListForUserRow), pog.QueryError) {
  let decoder = {
    use task_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use x <- decode.field(2, decode.int)
    use y <- decode.field(3, decode.int)
    use updated_at <- decode.field(4, decode.string)
    decode.success(TaskPositionsListForUserRow(
      task_id:,
      user_id:,
      x:,
      y:,
      updated_at:,
    ))
  }

  "-- name: task_positions_list_for_user
select
  tp.task_id,
  tp.user_id,
  tp.x,
  tp.y,
  to_char(tp.updated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as updated_at
from task_positions tp
join tasks t on t.id = tp.task_id
where tp.user_id = $1
  and ($2 = 0 or t.project_id = $2)
  and exists(
    select 1
    from project_members pm
    where pm.project_id = t.project_id
      and pm.user_id = $1
  )
order by tp.task_id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_positions_upsert` query
/// defined in `./src/scrumbringer_server/sql/task_positions_upsert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskPositionsUpsertRow {
  TaskPositionsUpsertRow(
    task_id: Int,
    user_id: Int,
    x: Int,
    y: Int,
    updated_at: String,
  )
}

/// name: task_positions_upsert
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_positions_upsert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
  arg_4: Int,
) -> Result(pog.Returned(TaskPositionsUpsertRow), pog.QueryError) {
  let decoder = {
    use task_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use x <- decode.field(2, decode.int)
    use y <- decode.field(3, decode.int)
    use updated_at <- decode.field(4, decode.string)
    decode.success(TaskPositionsUpsertRow(
      task_id:,
      user_id:,
      x:,
      y:,
      updated_at:,
    ))
  }

  "-- name: task_positions_upsert
insert into task_positions (task_id, user_id, x, y, updated_at)
values ($1, $2, $3, $4, now())
on conflict (task_id, user_id) do update
set x = $3,
    y = $4,
    updated_at = now()
returning
  task_id,
  user_id,
  x,
  y,
  to_char(updated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as updated_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_types_create` query
/// defined in `./src/scrumbringer_server/sql/task_types_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTypesCreateRow {
  TaskTypesCreateRow(
    id: Int,
    project_id: Int,
    name: String,
    icon: String,
    capability_id: Int,
  )
}

/// name: create_task_type
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_types_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: Int,
) -> Result(pog.Returned(TaskTypesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use icon <- decode.field(3, decode.string)
    use capability_id <- decode.field(4, decode.int)
    decode.success(TaskTypesCreateRow(
      id:,
      project_id:,
      name:,
      icon:,
      capability_id:,
    ))
  }

  "-- name: create_task_type
insert into task_types (project_id, name, icon, capability_id)
values ($1, $2, $3, nullif($4, 0))
returning
  id,
  project_id,
  name,
  icon,
  coalesce(capability_id, 0) as capability_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_types_is_in_project` query
/// defined in `./src/scrumbringer_server/sql/task_types_is_in_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTypesIsInProjectRow {
  TaskTypesIsInProjectRow(ok: Bool)
}

/// name: task_type_is_in_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_types_is_in_project(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(TaskTypesIsInProjectRow), pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.bool)
    decode.success(TaskTypesIsInProjectRow(ok:))
  }

  "-- name: task_type_is_in_project
select exists(
  select 1
  from task_types
  where id = $1
    and project_id = $2
) as ok;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_types_list` query
/// defined in `./src/scrumbringer_server/sql/task_types_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTypesListRow {
  TaskTypesListRow(
    id: Int,
    project_id: Int,
    name: String,
    icon: String,
    capability_id: Int,
  )
}

/// name: list_task_types_for_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_types_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(TaskTypesListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use icon <- decode.field(3, decode.string)
    use capability_id <- decode.field(4, decode.int)
    decode.success(TaskTypesListRow(
      id:,
      project_id:,
      name:,
      icon:,
      capability_id:,
    ))
  }

  "-- name: list_task_types_for_project
select
  id,
  project_id,
  name,
  icon,
  coalesce(capability_id, 0) as capability_id
from task_types
where project_id = $1
order by name asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_claim` query
/// defined in `./src/scrumbringer_server/sql/tasks_claim.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksClaimRow {
  TasksClaimRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
  )
}

/// name: claim_task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_claim(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(TasksClaimRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    decode.success(TasksClaimRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
    ))
  }

  "-- name: claim_task
update tasks
set
  claimed_by = $2,
  claimed_at = now(),
  status = 'claimed',
  version = version + 1
where id = $1
  and status = 'available'
  and version = $3
returning
  id,
  project_id,
  type_id,
  title,
  coalesce(description, '') as description,
  priority,
  status,
  created_by,
  coalesce(claimed_by, 0) as claimed_by,
  coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  version;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_complete` query
/// defined in `./src/scrumbringer_server/sql/tasks_complete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksCompleteRow {
  TasksCompleteRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
  )
}

/// name: complete_task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_complete(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(TasksCompleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    decode.success(TasksCompleteRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
    ))
  }

  "-- name: complete_task
update tasks
set
  status = 'completed',
  completed_at = now(),
  version = version + 1
where id = $1
  and status = 'claimed'
  and claimed_by = $2
  and version = $3
returning
  id,
  project_id,
  type_id,
  title,
  coalesce(description, '') as description,
  priority,
  status,
  created_by,
  coalesce(claimed_by, 0) as claimed_by,
  coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  version;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_create` query
/// defined in `./src/scrumbringer_server/sql/tasks_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksCreateRow {
  TasksCreateRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
  )
}

/// name: create_task
/// Create a new task in a project, ensuring the task type belongs to the project.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: Int,
) -> Result(pog.Returned(TasksCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    decode.success(TasksCreateRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
    ))
  }

  "-- name: create_task
-- Create a new task in a project, ensuring the task type belongs to the project.
with type_ok as (
  select id
  from task_types
  where id = $1
    and project_id = $2
)
insert into tasks (project_id, type_id, title, description, priority, created_by)
select
  $2,
  type_ok.id,
  $3,
  nullif($4, ''),
  $5,
  $6
from type_ok
returning
  id,
  project_id,
  type_id,
  title,
  coalesce(description, '') as description,
  priority,
  status,
  created_by,
  coalesce(claimed_by, 0) as claimed_by,
  coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  version;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_get_for_user` query
/// defined in `./src/scrumbringer_server/sql/tasks_get_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksGetForUserRow {
  TasksGetForUserRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
  )
}

/// name: get_task_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_get_for_user(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(TasksGetForUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    decode.success(TasksGetForUserRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
    ))
  }

  "-- name: get_task_for_user
select
  t.id,
  t.project_id,
  t.type_id,
  t.title,
  coalesce(t.description, '') as description,
  t.priority,
  t.status,
  t.created_by,
  coalesce(t.claimed_by, 0) as claimed_by,
  coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  t.version
from tasks t
where t.id = $1
  and exists(
    select 1
    from project_members pm
    where pm.project_id = t.project_id
      and pm.user_id = $2
  );
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_list` query
/// defined in `./src/scrumbringer_server/sql/tasks_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksListRow {
  TasksListRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
  )
}

/// name: list_tasks_for_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: Int,
  arg_4: Int,
  arg_5: String,
) -> Result(pog.Returned(TasksListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    decode.success(TasksListRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
    ))
  }

  "-- name: list_tasks_for_project
select
  t.id,
  t.project_id,
  t.type_id,
  t.title,
  coalesce(t.description, '') as description,
  t.priority,
  t.status,
  t.created_by,
  coalesce(t.claimed_by, 0) as claimed_by,
  coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  t.version
from tasks t
join task_types tt on tt.id = t.type_id
where t.project_id = $1
  and ($2 = '' or t.status = $2)
  and ($3 = 0 or t.type_id = $3)
  and ($4 = 0 or tt.capability_id = $4)
  and (
    $5 = ''
    or t.title ilike ('%' || $5 || '%')
    or t.description ilike ('%' || $5 || '%')
  )
order by t.created_at desc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_release` query
/// defined in `./src/scrumbringer_server/sql/tasks_release.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksReleaseRow {
  TasksReleaseRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
  )
}

/// name: release_task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_release(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(TasksReleaseRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    decode.success(TasksReleaseRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
    ))
  }

  "-- name: release_task
update tasks
set
  claimed_by = null,
  claimed_at = null,
  status = 'available',
  version = version + 1
where id = $1
  and status = 'claimed'
  and claimed_by = $2
  and version = $3
returning
  id,
  project_id,
  type_id,
  title,
  coalesce(description, '') as description,
  priority,
  status,
  created_by,
  coalesce(claimed_by, 0) as claimed_by,
  coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  version;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_update` query
/// defined in `./src/scrumbringer_server/sql/tasks_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksUpdateRow {
  TasksUpdateRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
  )
}

/// name: update_task_claimed_by_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_update(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: Int,
  arg_7: Int,
) -> Result(pog.Returned(TasksUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    decode.success(TasksUpdateRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
    ))
  }

  "-- name: update_task_claimed_by_user
update tasks
set
  title = case when $3 = '__unset__' then title else $3 end,
  description = case when $4 = '__unset__' then description else nullif($4, '') end,
  priority = case when $5 = -1 then priority else $5 end,
  type_id = case when $6 = -1 then type_id else $6 end,
  version = version + 1
where id = $1
  and claimed_by = $2
  and status = 'claimed'
  and version = $7
returning
  id,
  project_id,
  type_id,
  title,
  coalesce(description, '') as description,
  priority,
  status,
  created_by,
  coalesce(claimed_by, 0) as claimed_by,
  coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  version;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.int(arg_7))
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
