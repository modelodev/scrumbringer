//// Integration user persistence.

import domain/org_role
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import pog
import scrumbringer_server/services/persisted_field
import scrumbringer_server/services/persisted_role

pub type IntegrationUser {
  IntegrationUser(
    id: Int,
    email: String,
    org_role: org_role.OrgRole,
    created_at: String,
    active_token_count: Int,
  )
}

pub type IntegrationUserError {
  EmailRequired
  EmailTaken
  NotFound
  HasActiveTokens
  InvalidPersistedRole(String)
  DbError(pog.QueryError)
}

pub fn find_or_create(
  db: pog.Connection,
  org_id: Int,
  email: String,
) -> Result(IntegrationUser, IntegrationUserError) {
  use email <- result.try(validate_email(email))

  case find_by_email(db, org_id, email) {
    Ok(user) -> Ok(user)
    Error(NotFound) -> create(db, org_id, email)
    Error(error) -> Error(error)
  }
}

pub fn create(
  db: pog.Connection,
  org_id: Int,
  email: String,
) -> Result(IntegrationUser, IntegrationUserError) {
  use email <- result.try(validate_email(email))

  let decoder = integration_user_decoder()

  use returned <- result.try(
    pog.query(
      "\ninsert into users (email, password_hash, org_id, org_role, user_kind)\nvalues ($1, null, $2, 'member', 'integration')\nreturning id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at, 0::int as active_token_count\n",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
    |> result.map_error(map_insert_error),
  )

  use row <- result.try(
    persisted_field.query_row(returned.rows)
    |> result.map_error(fn(_) { NotFound }),
  )
  integration_user_from_row(row)
}

pub fn list_for_org(
  db: pog.Connection,
  org_id: Int,
) -> Result(List(IntegrationUser), IntegrationUserError) {
  use returned <- result.try(
    pog.query(
      integration_user_select()
      <> "\nwhere u.org_id = $1 and u.user_kind = 'integration' and u.deleted_at is null\ngroup by u.id, u.email, u.org_role, u.created_at\norder by u.email\n",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(integration_user_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.try_map(integration_user_from_row)
}

pub fn deactivate(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(Nil, IntegrationUserError) {
  use user <- result.try(find_by_id(db, org_id, user_id))

  case user.active_token_count {
    0 -> soft_delete(db, org_id, user_id)
    _ -> Error(HasActiveTokens)
  }
}

fn find_by_email(
  db: pog.Connection,
  org_id: Int,
  email: String,
) -> Result(IntegrationUser, IntegrationUserError) {
  use returned <- result.try(
    pog.query(
      integration_user_select()
      <> "\nwhere u.org_id = $1 and u.email = $2 and u.user_kind = 'integration' and u.deleted_at is null\ngroup by u.id, u.email, u.org_role, u.created_at\n",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.text(email))
    |> pog.returning(integration_user_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  use row <- result.try(
    persisted_field.query_row(returned.rows)
    |> result.map_error(fn(_) { NotFound }),
  )
  integration_user_from_row(row)
}

fn find_by_id(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(IntegrationUser, IntegrationUserError) {
  use returned <- result.try(
    pog.query(
      integration_user_select()
      <> "\nwhere u.org_id = $1 and u.id = $2 and u.user_kind = 'integration' and u.deleted_at is null\ngroup by u.id, u.email, u.org_role, u.created_at\n",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(integration_user_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  use row <- result.try(
    persisted_field.query_row(returned.rows)
    |> result.map_error(fn(_) { NotFound }),
  )
  integration_user_from_row(row)
}

fn soft_delete(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(Nil, IntegrationUserError) {
  use returned <- result.try(
    pog.query(
      "\nupdate users\nset deleted_at = coalesce(deleted_at, now())\nwhere org_id = $1 and id = $2 and user_kind = 'integration' and deleted_at is null\nreturning 1\n",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  case returned.rows {
    [] -> Error(NotFound)
    _ -> Ok(Nil)
  }
}

fn validate_email(email: String) -> Result(String, IntegrationUserError) {
  let trimmed = string.trim(email)
  case trimmed {
    "" -> Error(EmailRequired)
    _ -> Ok(trimmed)
  }
}

type IntegrationUserRow {
  IntegrationUserRow(
    id: Int,
    email: String,
    org_role: String,
    created_at: String,
    active_token_count: Int,
  )
}

fn integration_user_decoder() {
  use id <- decode.field(0, decode.int)
  use email <- decode.field(1, decode.string)
  use org_role <- decode.field(2, decode.string)
  use created_at <- decode.field(3, decode.string)
  use active_token_count <- decode.field(4, decode.int)
  decode.success(IntegrationUserRow(
    id:,
    email:,
    org_role:,
    created_at:,
    active_token_count:,
  ))
}

fn integration_user_from_row(
  row: IntegrationUserRow,
) -> Result(IntegrationUser, IntegrationUserError) {
  use role <- result.try(
    persisted_role.org_role(row.org_role)
    |> result.map_error(fn(_) { InvalidPersistedRole(row.org_role) }),
  )

  Ok(IntegrationUser(
    id: row.id,
    email: row.email,
    org_role: role,
    created_at: row.created_at,
    active_token_count: row.active_token_count,
  ))
}

fn integration_user_select() -> String {
  "\nselect\n  u.id,\n  u.email,\n  u.org_role,\n  to_char(u.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,\n  count(t.id)::int as active_token_count\nfrom users u\nleft join api_tokens t\n  on t.integration_user_id = u.id\n  and t.revoked_at is null\n  and (t.expires_at is null or t.expires_at > now())\n"
}

fn map_insert_error(error: pog.QueryError) -> IntegrationUserError {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      case string.contains(constraint, "users_email") {
        True -> EmailTaken
        False -> DbError(error)
      }
    _ -> DbError(error)
  }
}
