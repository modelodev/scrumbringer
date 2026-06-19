//// Database operations for organization user membership.
////
//// ## Mission
////
//// Provides data access layer for users within organizations.
////
//// ## Responsibilities
////
//// - List users belonging to an organization
//// - Update user organization roles
//// - Validate role changes (prevent demoting last admin)
////
//// ## Non-responsibilities
////
//// - HTTP request handling (see `http/org_users.gleam`)
//// - Authentication (see `use_case/auth_logic.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for queries

import domain/org_role.{type OrgRole}
import gleam/dynamic/decode
import gleam/list
import gleam/option as opt
import gleam/result
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/persisted_role

/// Organization user record with role.
pub type OrgUser {
  OrgUser(id: Int, email: String, org_role: OrgRole, created_at: String)
}

/// Errors returned when updating a user's org role.
pub type UpdateOrgRoleError {
  UpdateUserNotFound
  UpdateCannotDemoteLastAdmin
  UpdateDbError(pog.QueryError)
}

/// Errors returned when deleting an organization user.
pub type DeleteOrgUserError {
  DeleteUserNotFound
  DeleteLastAdmin
  DeleteDbError(pog.QueryError)
}

/// Lists organization users, optionally filtered by query.
///
/// Example:
///   list_org_users(db, org_id, "alex")
pub fn list_org_users(
  db: pog.Connection,
  org_id: Int,
  q: String,
) -> Result(List(OrgUser), pog.QueryError) {
  use returned <- result.try(sql.org_users_list(db, org_id, q))

  returned.rows
  |> list.try_map(fn(row) {
    org_user_from_fields(row.id, row.email, row.org_role, row.created_at)
  })
}

type OrgUserRow {
  OrgUserRow(id: Int, email: String, org_role: String, created_at: String)
}

fn org_user_row_decoder() -> decode.Decoder(OrgUserRow) {
  use id <- decode.field(0, decode.int)
  use email <- decode.field(1, decode.string)
  use org_role <- decode.field(2, decode.string)
  use created_at <- decode.field(3, decode.string)
  decode.success(OrgUserRow(id:, email:, org_role:, created_at:))
}

/// Updates a user's organization role.
///
/// Example:
///   update_org_role(db, org_id, user_id, org_role.Admin)
pub fn update_org_role(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
  new_role: OrgRole,
) -> Result(OrgUser, UpdateOrgRoleError) {
  pog.transaction(db, fn(tx) {
    use existing <- result.try(
      fetch_user_for_update(tx, org_id, user_id)
      |> result.map_error(UpdateDbError),
    )
    use row <- result.try(require_user_row(existing))
    use current_user <- result.try(
      org_user_from_row(row)
      |> result.map_error(UpdateDbError),
    )

    use _ <- result.try(ensure_can_demote(
      tx,
      org_id,
      current_user.org_role,
      new_role,
    ))

    case current_user.org_role == new_role {
      True -> Ok(current_user)
      False -> {
        use row <- result.try(update_role_row(tx, org_id, user_id, new_role))
        org_user_from_row(row)
        |> result.map_error(UpdateDbError)
      }
    }
  })
  |> result.map_error(transaction_error_to_update_error)
}

fn org_user_from_fields(
  id: Int,
  email: String,
  role_value: String,
  created_at: String,
) -> Result(OrgUser, pog.QueryError) {
  use role <- result.try(persisted_role.org_role(role_value))
  Ok(OrgUser(id: id, email: email, org_role: role, created_at: created_at))
}

fn org_user_from_row(row: OrgUserRow) -> Result(OrgUser, pog.QueryError) {
  let OrgUserRow(
    id: id,
    email: email,
    org_role: role_value,
    created_at: created_at,
  ) = row

  org_user_from_fields(id, email, role_value, created_at)
}

/// Soft-delete a user from an organization.
///
/// Example:
///   delete_org_user(db, org_id, user_id)
pub fn delete_org_user(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(OrgUser, DeleteOrgUserError) {
  pog.transaction(db, fn(tx) {
    use existing <- result.try(
      fetch_user_for_update(tx, org_id, user_id)
      |> result.map_error(DeleteDbError),
    )
    use row <- result.try(require_user_row_for_delete(existing))
    use current_user <- result.try(
      org_user_from_row(row)
      |> result.map_error(DeleteDbError),
    )

    use _ <- result.try(ensure_can_delete(tx, org_id, current_user.org_role))

    use row <- result.try(soft_delete_row(tx, org_id, user_id))
    org_user_from_row(row)
    |> result.map_error(DeleteDbError)
  })
  |> result.map_error(transaction_error_to_delete_error)
}

fn require_user_row(
  row: opt.Option(OrgUserRow),
) -> Result(OrgUserRow, UpdateOrgRoleError) {
  case row {
    opt.None -> Error(UpdateUserNotFound)
    opt.Some(row) -> Ok(row)
  }
}

fn require_user_row_for_delete(
  row: opt.Option(OrgUserRow),
) -> Result(OrgUserRow, DeleteOrgUserError) {
  case row {
    opt.None -> Error(DeleteUserNotFound)
    opt.Some(row) -> Ok(row)
  }
}

fn ensure_can_demote(
  tx,
  org_id: Int,
  current_role: OrgRole,
  new_role: OrgRole,
) -> Result(Nil, UpdateOrgRoleError) {
  case current_role == org_role.Admin && new_role == org_role.Member {
    True -> {
      use admin_count <- result.try(
        count_org_admins(tx, org_id)
        |> result.map_error(UpdateDbError),
      )
      case is_last_admin(admin_count) {
        True -> Error(UpdateCannotDemoteLastAdmin)
        False -> Ok(Nil)
      }
    }

    False -> Ok(Nil)
  }
}

fn ensure_can_delete(
  tx,
  org_id: Int,
  current_role: OrgRole,
) -> Result(Nil, DeleteOrgUserError) {
  case current_role == org_role.Admin {
    True -> {
      use admin_count <- result.try(
        count_org_admins(tx, org_id)
        |> result.map_error(DeleteDbError),
      )
      case is_last_admin(admin_count) {
        True -> Error(DeleteLastAdmin)
        False -> Ok(Nil)
      }
    }
    False -> Ok(Nil)
  }
}

fn is_last_admin(admin_count: Int) -> Bool {
  admin_count <= 1
}

fn fetch_user_for_update(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(opt.Option(OrgUserRow), pog.QueryError) {
  use returned <- result.try(
    pog.query(
      "select id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at from users where org_id = $1 and id = $2 and deleted_at is null for update",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(org_user_row_decoder())
    |> pog.execute(db),
  )

  case returned.rows {
    [row, ..] -> Ok(opt.Some(row))
    [] -> Ok(opt.None)
  }
}

fn count_org_admins(
  db: pog.Connection,
  org_id: Int,
) -> Result(Int, pog.QueryError) {
  use returned <- result.try(
    pog.query(
      "select count(*) from users where org_id = $1 and org_role = 'admin' and deleted_at is null",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db),
  )

  persisted_field.query_row(returned.rows)
}

fn update_role_row(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
  new_role: OrgRole,
) -> Result(OrgUserRow, UpdateOrgRoleError) {
  let org_role_value = org_role.to_string(new_role)

  case
    pog.query(
      "update users set org_role = $3 where org_id = $1 and id = $2 and deleted_at is null returning id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(org_role_value))
    |> pog.returning(org_user_row_decoder())
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row)
    Ok(pog.Returned(rows: [], ..)) -> Error(UpdateUserNotFound)
    Error(e) -> Error(UpdateDbError(e))
  }
}

fn soft_delete_row(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(OrgUserRow, DeleteOrgUserError) {
  case
    pog.query(
      "update users set deleted_at = now() where org_id = $1 and id = $2 and deleted_at is null returning id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(org_user_row_decoder())
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row)
    Ok(pog.Returned(rows: [], ..)) -> Error(DeleteUserNotFound)
    Error(e) -> Error(DeleteDbError(e))
  }
}

fn transaction_error_to_update_error(
  error: pog.TransactionError(UpdateOrgRoleError),
) -> UpdateOrgRoleError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> UpdateDbError(err)
  }
}

fn transaction_error_to_delete_error(
  error: pog.TransactionError(DeleteOrgUserError),
) -> DeleteOrgUserError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> DeleteDbError(err)
  }
}
