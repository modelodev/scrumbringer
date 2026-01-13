import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_domain/org_role
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/password
import scrumbringer_server/services/store_state.{type StoredUser, StoredUser}

pub fn register(
  db: pog.Connection,
  email: String,
  password_raw: String,
  org_name: Option(String),
  invite_code: Option(String),
  _now_iso: String,
  _now_unix: Int,
) -> Result(StoredUser, auth_logic.AuthError) {
  use org_exists <- result.try(
    organization_exists(db)
    |> result.map_error(auth_logic.DbError),
  )

  case org_exists {
    True -> invite_register(db, email, password_raw, invite_code)
    False -> bootstrap_register(db, email, password_raw, org_name)
  }
}

pub fn login(
  db: pog.Connection,
  email: String,
  password_raw: String,
) -> Result(StoredUser, auth_logic.AuthError) {
  use maybe_row <- result.try(
    find_user_by_email(db, email)
    |> result.map_error(auth_logic.DbError),
  )

  use row <- result.try(case maybe_row {
    Some(row) -> Ok(row)
    None -> Error(auth_logic.InvalidCredentials)
  })

  use user <- result.try(user_from_row(row))

  use matched <- result.try(
    password.verify(password_raw, user.password_hash)
    |> result.map_error(auth_logic.PasswordError),
  )

  case matched {
    True -> Ok(user)
    False -> Error(auth_logic.InvalidCredentials)
  }
}

pub fn get_user(db: pog.Connection, user_id: Int) -> Result(StoredUser, Nil) {
  case find_user_by_id(db, user_id) {
    Ok(Some(row)) -> user_from_row(row) |> result.replace_error(Nil)
    _ -> Error(Nil)
  }
}

type UserRow {
  UserRow(
    id: Int,
    email: String,
    password_hash: String,
    org_id: Int,
    org_role: String,
    created_at: String,
  )
}

fn user_from_row(row: UserRow) -> Result(StoredUser, auth_logic.AuthError) {
  use parsed_role <- result.try(
    org_role.parse(row.org_role)
    |> result.replace_error(
      auth_logic.DbError(pog.PostgresqlError(
        code: "DATA",
        name: "corrupt_data",
        message: "Invalid org_role",
      )),
    ),
  )

  Ok(StoredUser(
    id: row.id,
    email: row.email,
    password_hash: row.password_hash,
    org_id: row.org_id,
    org_role: parsed_role,
    created_at: row.created_at,
  ))
}

fn bootstrap_register(
  db: pog.Connection,
  email: String,
  password_raw: String,
  org_name: Option(String),
) -> Result(StoredUser, auth_logic.AuthError) {
  let org_name = case org_name {
    Some(name) if name != "" -> Ok(name)
    _ -> Error(auth_logic.OrgNameRequired)
  }

  use org_name <- result.try(org_name)

  use password_hash <- result.try(
    password.hash(password_raw)
    |> result.map_error(auth_logic.PasswordError),
  )

  pog.transaction(db, fn(tx) {
    use org_id <- result.try(
      insert_organization(tx, org_name)
      |> result.map_error(auth_logic.DbError),
    )

    use project_id <- result.try(
      insert_default_project(tx, org_id)
      |> result.map_error(auth_logic.DbError),
    )

    use user_row <- result.try(
      insert_user(tx, email, password_hash, org_id, "admin")
      |> result.map_error(map_user_insert_error),
    )

    let #(user_id, created_at) = user_row

    use _ <- result.try(
      insert_project_member(tx, project_id, user_id, "admin")
      |> result.map_error(auth_logic.DbError),
    )

    Ok(StoredUser(
      id: user_id,
      email: email,
      password_hash: password_hash,
      org_id: org_id,
      org_role: org_role.Admin,
      created_at: created_at,
    ))
  })
  |> result.map_error(transaction_error_to_auth_error)
}

fn invite_register(
  db: pog.Connection,
  email: String,
  password_raw: String,
  invite_code: Option(String),
) -> Result(StoredUser, auth_logic.AuthError) {
  let invite_code = case invite_code {
    Some(code) if code != "" -> Ok(code)
    _ -> Error(auth_logic.InviteRequired)
  }
  use invite_code <- result.try(invite_code)

  use password_hash <- result.try(
    password.hash(password_raw)
    |> result.map_error(auth_logic.PasswordError),
  )

  pog.transaction(db, fn(tx) {
    use invite <- result.try(
      get_invite_status(tx, invite_code)
      |> result.map_error(auth_logic.DbError),
    )

    case invite {
      InviteMissing -> Error(auth_logic.InviteInvalid)
      InviteUsed -> Error(auth_logic.InviteUsed)
      InviteExpired -> Error(auth_logic.InviteExpired)
      InviteOk(org_id) -> {
        use user_row <- result.try(
          insert_user(tx, email, password_hash, org_id, "member")
          |> result.map_error(map_user_insert_error),
        )

        let #(user_id, created_at) = user_row

        use _ <- result.try(
          mark_invite_used(tx, invite_code, user_id)
          |> result.map_error(auth_logic.DbError),
        )

        Ok(StoredUser(
          id: user_id,
          email: email,
          password_hash: password_hash,
          org_id: org_id,
          org_role: org_role.Member,
          created_at: created_at,
        ))
      }
    }
  })
  |> result.map_error(transaction_error_to_auth_error)
}

type InviteStatus {
  InviteMissing
  InviteUsed
  InviteExpired
  InviteOk(Int)
}

type InviteRow {
  InviteRow(org_id: Int, used: Bool, expired: Bool)
}

fn get_invite_status(
  db: pog.Connection,
  code: String,
) -> Result(InviteStatus, pog.QueryError) {
  let decoder = {
    use org_id <- decode.field(0, decode.int)
    use used <- decode.field(1, decode.bool)
    use expired <- decode.field(2, decode.bool)
    decode.success(InviteRow(org_id:, used:, expired:))
  }

  use returned <- result.try(
    pog.query(
      "\nselect\n  org_id,\n  (used_at is not null) as used,\n  (expires_at is not null and expires_at < now()) as expired\nfrom\n  org_invites\nwhere\n  code = $1\nfor update\n",
    )
    |> pog.parameter(pog.text(code))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(InviteMissing)
    [InviteRow(used: True, ..), ..] -> Ok(InviteUsed)
    [InviteRow(expired: True, ..), ..] -> Ok(InviteExpired)
    [InviteRow(org_id: org_id, ..), ..] -> Ok(InviteOk(org_id))
  }
}

fn mark_invite_used(
  db: pog.Connection,
  code: String,
  used_by: Int,
) -> Result(Nil, pog.QueryError) {
  pog.query(
    "update org_invites set used_at = now(), used_by = $2 where code = $1",
  )
  |> pog.parameter(pog.text(code))
  |> pog.parameter(pog.int(used_by))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

fn organization_exists(db: pog.Connection) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use exists <- decode.field(0, decode.bool)
    decode.success(exists)
  }

  use returned <- result.try(
    pog.query("select exists(select 1 from organizations)")
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [exists, ..] -> Ok(exists)
    _ -> Ok(False)
  }
}

fn find_user_by_email(
  db: pog.Connection,
  email: String,
) -> Result(Option(UserRow), pog.QueryError) {
  query_user_row(db, "where email = $1", [pog.text(email)])
}

fn find_user_by_id(
  db: pog.Connection,
  user_id: Int,
) -> Result(Option(UserRow), pog.QueryError) {
  query_user_row(db, "where id = $1", [pog.int(user_id)])
}

fn query_user_row(
  db: pog.Connection,
  where_clause: String,
  params: List(pog.Value),
) -> Result(Option(UserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    use org_id <- decode.field(3, decode.int)
    use org_role <- decode.field(4, decode.string)
    use created_at <- decode.field(5, decode.string)
    decode.success(UserRow(
      id:,
      email:,
      password_hash:,
      org_id:,
      org_role:,
      created_at:,
    ))
  }

  let query =
    pog.query(
      "\nselect\n  id,\n  email,\n  password_hash,\n  org_id,\n  org_role,\n  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at\nfrom\n  users\n"
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

fn insert_organization(
  db: pog.Connection,
  name: String,
) -> Result(Int, pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(id)
  }

  use returned <- result.try(
    pog.query("insert into organizations (name) values ($1) returning id")
    |> pog.parameter(pog.text(name))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  let assert [id] = returned.rows
  Ok(id)
}

fn insert_default_project(
  db: pog.Connection,
  org_id: Int,
) -> Result(Int, pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(id)
  }

  use returned <- result.try(
    pog.query(
      "insert into projects (org_id, name) values ($1, 'Default') returning id",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  let assert [id] = returned.rows
  Ok(id)
}

fn insert_user(
  db: pog.Connection,
  email: String,
  password_hash: String,
  org_id: Int,
  org_role: String,
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
    |> pog.parameter(pog.text(org_role))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  let assert [row] = returned.rows
  Ok(row)
}

fn insert_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: String,
) -> Result(Nil, pog.QueryError) {
  pog.query(
    "insert into project_members (project_id, user_id, role) values ($1, $2, $3)",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.text(role))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

fn map_user_insert_error(error: pog.QueryError) -> auth_logic.AuthError {
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

fn transaction_error_to_auth_error(
  error: pog.TransactionError(auth_logic.AuthError),
) -> auth_logic.AuthError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> auth_logic.DbError(err)
  }
}
