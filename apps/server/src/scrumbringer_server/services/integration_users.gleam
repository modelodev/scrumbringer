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
  )
}

pub type IntegrationUserError {
  EmailRequired
  EmailTaken
  NotFound
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
      "\ninsert into users (email, password_hash, org_id, org_role, user_kind)\nvalues ($1, null, $2, 'member', 'integration')\nreturning id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at\n",
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
      "\nselect id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at\nfrom users\nwhere org_id = $1 and user_kind = 'integration' and deleted_at is null\norder by email\n",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(integration_user_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.try_map(integration_user_from_row)
}

fn find_by_email(
  db: pog.Connection,
  org_id: Int,
  email: String,
) -> Result(IntegrationUser, IntegrationUserError) {
  use returned <- result.try(
    pog.query(
      "\nselect id, email, org_role, to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at\nfrom users\nwhere org_id = $1 and email = $2 and user_kind = 'integration' and deleted_at is null\n",
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
  )
}

fn integration_user_decoder() {
  use id <- decode.field(0, decode.int)
  use email <- decode.field(1, decode.string)
  use org_role <- decode.field(2, decode.string)
  use created_at <- decode.field(3, decode.string)
  decode.success(IntegrationUserRow(id:, email:, org_role:, created_at:))
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
  ))
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
