//// Authentication database queries.
////
//// ## Mission
////
//// Provides low-level database access for authentication operations including
//// user lookups, organization checks, and user/project creation.
////
//// This package is the formal SQL boundary for authentication. It is separate
//// from `use_case/*_db.gleam` so auth flows can share bootstrap/login queries
//// without making credential logic a generic service module.
////
//// ## Responsibilities
////
//// - Query users by email or ID
//// - Check organization existence
//// - Insert organizations, users, and project members
//// - Update user login timestamps
////
//// ## Relations
////
//// - **registration.gleam**: Uses these queries for registration flows
//// - **login.gleam**: Uses these queries for login flow

import domain/org_role
import domain/project_role
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/use_case/auth_logic
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/persisted_role
import scrumbringer_server/use_case/store_state

// =============================================================================
// Types
// =============================================================================

/// Internal user row from database.
pub type UserRow {
  UserRow(
    id: Int,
    email: String,
    password_hash: Option(String),
    org_id: Int,
    org_role: String,
    user_kind: String,
    created_at: String,
  )
}

// =============================================================================
// User Queries
// =============================================================================

/// Find user by email.
pub fn find_user_by_email(
  db: pog.Connection,
  email: String,
) -> Result(Option(UserRow), pog.QueryError) {
  query_user_row(db, "where deleted_at is null and email = $1", [
    pog.text(email),
  ])
}

/// Find user by ID.
pub fn find_user_by_id(
  db: pog.Connection,
  user_id: Int,
) -> Result(Option(UserRow), pog.QueryError) {
  query_user_row(db, "where deleted_at is null and id = $1", [pog.int(user_id)])
}

/// Convert UserRow to StoredUser.
pub fn user_from_row(
  row: UserRow,
) -> Result(store_state.StoredUser, auth_logic.AuthError) {
  use parsed_role <- result.try(
    persisted_role.org_role(row.org_role)
    |> result.map_error(auth_logic.DbError),
  )
  use identity <- result.try(
    store_state.parse_user_identity(row.user_kind, row.password_hash)
    |> result.map_error(fn(error) {
      case error {
        store_state.UnknownUserIdentityKind(value) ->
          auth_logic.InvalidPersistedUserKind(value)
        store_state.HumanIdentityMissingPassword ->
          auth_logic.InvalidPersistedUserIdentity("human_missing_password")
        store_state.IntegrationIdentityHasPassword ->
          auth_logic.InvalidPersistedUserIdentity("integration_has_password")
      }
    }),
  )

  Ok(store_state.StoredUser(
    id: row.id,
    email: row.email,
    identity: identity,
    org_id: row.org_id,
    org_role: parsed_role,
    created_at: row.created_at,
  ))
}

/// Set first_login_at if not already set.
pub fn set_first_login_at_if_missing(
  db: pog.Connection,
  user_id: Int,
) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(
    pog.query(
      "update users set first_login_at = coalesce(first_login_at, now()) where id = $1 returning 1",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(False)
    _ -> Ok(True)
  }
}

// =============================================================================
// Organization Queries
// =============================================================================

/// Check if any organization exists.
pub fn organization_exists(db: pog.Connection) -> Result(Bool, pog.QueryError) {
  use returned <- result.try(
    pog.query("select exists(select 1 from organizations)")
    |> pog.returning(persisted_field.bool_decoder())
    |> pog.execute(db),
  )

  persisted_field.query_row(returned.rows)
}

/// Insert a new organization.
pub fn insert_organization(
  db: pog.Connection,
  name: String,
) -> Result(Int, pog.QueryError) {
  use returned <- result.try(
    pog.query("insert into organizations (name) values ($1) returning id")
    |> pog.parameter(pog.text(name))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db),
  )

  persisted_field.query_row(returned.rows)
}

// =============================================================================
// Project Queries
// =============================================================================

/// Insert default project for organization.
pub fn insert_default_project(
  db: pog.Connection,
  org_id: Int,
) -> Result(Int, pog.QueryError) {
  use returned <- result.try(
    pog.query(
      "insert into projects (org_id, name) values ($1, 'Default') returning id",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db),
  )

  persisted_field.query_row(returned.rows)
}

/// Insert project member.
pub fn insert_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: project_role.ProjectRole,
) -> Result(Nil, pog.QueryError) {
  pog.query(
    "insert into project_members (project_id, user_id, role) values ($1, $2, $3)",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.text(project_role.to_string(role)))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

// =============================================================================
// User Insert
// =============================================================================

/// Insert a new user.
pub fn insert_user(
  db: pog.Connection,
  email: String,
  password_hash: String,
  org_id: Int,
  org_role: org_role.OrgRole,
) -> Result(#(Int, String), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use created_at <- decode.field(1, decode.string)
    decode.success(#(id, created_at))
  }

  use returned <- result.try(
    pog.query(
      "\ninsert into users (email, password_hash, org_id, org_role)\nvalues ($1, $2, $3, $4)\nreturning\n  id,\n  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at\n",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(password_hash))
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.text(org_role.to_string(org_role)))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  persisted_field.query_row(returned.rows)
}

/// Map user insert error to auth error.
pub fn map_user_insert_error(error: pog.QueryError) -> auth_logic.AuthError {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) -> {
      case string.contains(constraint, "users_email") {
        True -> auth_logic.EmailTaken
        False -> auth_logic.DbError(error)
      }
    }

    _ -> auth_logic.DbError(error)
  }
}

// =============================================================================
// Private Helpers
// =============================================================================

fn query_user_row(
  db: pog.Connection,
  where_clause: String,
  params: List(pog.Value),
) -> Result(Option(UserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.optional(decode.string))
    use org_id <- decode.field(3, decode.int)
    use org_role <- decode.field(4, decode.string)
    use user_kind <- decode.field(5, decode.string)
    use created_at <- decode.field(6, decode.string)
    decode.success(UserRow(
      id:,
      email:,
      password_hash:,
      org_id:,
      org_role:,
      user_kind:,
      created_at:,
    ))
  }

  let query =
    pog.query(
      "\nselect\n  id,\n  email,\n  password_hash,\n  org_id,\n  org_role,\n  user_kind,\n  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at\nfrom\n  users\n"
      <> where_clause
      <> "\nlimit 1\n",
    )

  let query =
    params
    |> list.fold(query, fn(query, param) { pog.parameter(query, param) })

  use returned <- result.try(
    query
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(None)
    [row, ..] -> Ok(Some(row))
  }
}

// =============================================================================
// Transaction Helpers
// =============================================================================

/// Convert transaction error to auth error.
pub fn transaction_error_to_auth_error(
  error: pog.TransactionError(auth_logic.AuthError),
) -> auth_logic.AuthError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> auth_logic.DbError(err)
  }
}
