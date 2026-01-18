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

import gleam/dynamic/decode
import gleam/list
import gleam/option as opt
import gleam/result
import pog
import scrumbringer_server/sql

pub type OrgUser {
  OrgUser(id: Int, email: String, org_role: String, created_at: String)
}

pub type UpdateOrgRoleError {
  UserNotFound
  CannotDemoteLastAdmin
  InvalidRole
  DbError(pog.QueryError)
}

pub fn list_org_users(
  db: pog.Connection,
  org_id: Int,
  q: String,
) -> Result(List(OrgUser), pog.QueryError) {
  use returned <- result.try(sql.org_users_list(db, org_id, q))

  returned.rows
  |> list.map(fn(row) {
    OrgUser(
      id: row.id,
      email: row.email,
      org_role: row.org_role,
      created_at: row.created_at,
    )
  })
  |> Ok
}

type OrgUserRow {
  OrgUserRow(id: Int, email: String, org_role: String, created_at: String)
}

pub fn update_org_role(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
  org_role: String,
) -> Result(OrgUser, UpdateOrgRoleError) {
  use _ <- result.try(validate_org_role(org_role))

  pog.transaction(db, fn(tx) {
    use existing <- result.try(
      fetch_user_for_update(tx, org_id, user_id)
      |> result.map_error(DbError),
    )

    case existing {
      opt.None -> Error(UserNotFound)

      opt.Some(row) -> {
        let OrgUserRow(org_role: current_role, ..) = row

        case current_role == "admin" && org_role == "member" {
          True -> {
            use admin_count <- result.try(
              count_org_admins(tx, org_id)
              |> result.map_error(DbError),
            )

            case admin_count <= 1 {
              True -> Error(CannotDemoteLastAdmin)
              False -> update_role_row(tx, org_id, user_id, org_role)
            }
          }

          False -> {
            case current_role == org_role {
              True -> Ok(row)
              False -> update_role_row(tx, org_id, user_id, org_role)
            }
          }
        }
      }
    }
  })
  |> result.map_error(transaction_error_to_update_error)
  |> result.map(fn(row) {
    let OrgUserRow(
      id: id,
      email: email,
      org_role: org_role,
      created_at: created_at,
    ) = row

    OrgUser(id: id, email: email, org_role: org_role, created_at: created_at)
  })
}

fn validate_org_role(value: String) -> Result(Nil, UpdateOrgRoleError) {
  case value {
    "admin" | "member" -> Ok(Nil)
    _ -> Error(InvalidRole)
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
      "select id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at from users where org_id = $1 and id = $2 for update",
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
      "select count(*) from users where org_id = $1 and org_role = 'admin'",
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
  org_role: String,
) -> Result(OrgUserRow, UpdateOrgRoleError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use org_role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(OrgUserRow(id:, email:, org_role:, created_at:))
  }

  case
    pog.query(
      "update users set org_role = $3 where org_id = $1 and id = $2 returning id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(org_role))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row)
    Ok(pog.Returned(rows: [], ..)) -> Error(UserNotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn transaction_error_to_update_error(
  error: pog.TransactionError(UpdateOrgRoleError),
) -> UpdateOrgRoleError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> DbError(err)
  }
}
