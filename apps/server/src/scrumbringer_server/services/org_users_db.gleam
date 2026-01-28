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
//// - Authentication (see `services/auth_logic.gleam`)
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

/// Organization user record with role.
pub type OrgUser {
  OrgUser(id: Int, email: String, org_role: OrgRole, created_at: String)
}

/// Errors returned when updating a user's org role.
pub type UpdateOrgRoleError {
  UpdateUserNotFound
  UpdateCannotDemoteLastAdmin
  UpdateInvalidRole
  UpdateDbError(pog.QueryError)
}

/// Errors returned when deleting an organization user.
pub type DeleteOrgUserError {
  DeleteUserNotFound
  DeleteLastAdmin
  DeleteDbError(pog.QueryError)
}

fn parse_org_role(value: String) -> Result(OrgRole, pog.QueryError) {
  case org_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) ->
      Error(pog.PostgresqlError(
        code: "INVALID_ROLE",
        name: "invalid_role",
        message: "Invalid org role: " <> value,
      ))
  }
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
    use role <- result.try(parse_org_role(row.org_role))
    Ok(OrgUser(
      id: row.id,
      email: row.email,
      org_role: role,
      created_at: row.created_at,
    ))
  })
}

type OrgUserRow {
  OrgUserRow(id: Int, email: String, org_role: String, created_at: String)
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

    let OrgUserRow(org_role: current_role, ..) = row
    use current_role <- result.try(
      parse_org_role(current_role)
      |> result.map_error(UpdateDbError),
    )
    use _ <- result.try(ensure_can_demote(tx, org_id, current_role, new_role))

    case current_role == new_role {
      True -> Ok(row)
      False -> update_role_row(tx, org_id, user_id, new_role)
    }
  })
  |> result.map_error(transaction_error_to_update_error)
  |> result.try(fn(row) {
    let OrgUserRow(
      id: id,
      email: email,
      org_role: role_value,
      created_at: created_at,
    ) = row
    use role <- result.try(
      parse_org_role(role_value) |> result.map_error(UpdateDbError),
    )
    Ok(OrgUser(id: id, email: email, org_role: role, created_at: created_at))
  })
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

    let OrgUserRow(org_role: current_role, ..) = row
    use current_role <- result.try(
      parse_org_role(current_role)
      |> result.map_error(DeleteDbError),
    )
    use _ <- result.try(ensure_can_delete(tx, org_id, current_role))

    soft_delete_row(tx, org_id, user_id)
  })
  |> result.map_error(transaction_error_to_delete_error)
  |> result.try(fn(row) {
    let OrgUserRow(
      id: id,
      email: email,
      org_role: role_value,
      created_at: created_at,
    ) = row
    use role <- result.try(
      parse_org_role(role_value) |> result.map_error(DeleteDbError),
    )
    Ok(OrgUser(id: id, email: email, org_role: role, created_at: created_at))
  })
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

// Justification: nested case improves clarity for branching logic.
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
      // Justification: nested case ensures the last admin is preserved.
      case admin_count <= 1 {
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
      case admin_count <= 1 {
        True -> Error(DeleteLastAdmin)
        False -> Ok(Nil)
      }
    }
    False -> Ok(Nil)
  }
}

fn fetch_user_for_update(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(opt.Option(OrgUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use org_role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(OrgUserRow(id:, email:, org_role:, created_at:))
  }

  use returned <- result.try(
    pog.query(
      "select id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at from users where org_id = $1 and id = $2 and deleted_at is null for update",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(decoder)
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
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  use returned <- result.try(
    pog.query(
      "select count(*) from users where org_id = $1 and org_role = 'admin' and deleted_at is null",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [count, ..] -> Ok(count)
    _ -> Ok(0)
  }
}

fn update_role_row(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
  new_role: OrgRole,
) -> Result(OrgUserRow, UpdateOrgRoleError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use org_role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(OrgUserRow(id:, email:, org_role:, created_at:))
  }
  let org_role_value = org_role.to_string(new_role)

  case
    pog.query(
      "update users set org_role = $3 where org_id = $1 and id = $2 and deleted_at is null returning id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(org_role_value))
    |> pog.returning(decoder)
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
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use org_role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(OrgUserRow(id:, email:, org_role:, created_at:))
  }

  case
    pog.query(
      "update users set deleted_at = now() where org_id = $1 and id = $2 and deleted_at is null returning id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(decoder)
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
