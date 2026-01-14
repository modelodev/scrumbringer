import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/int
import gleam/result
import gleam/string
import pog

pub const reset_token_ttl_hours = 24

pub type TokenStatus {
  TokenMissing
  TokenUsed
  TokenInvalidated
  TokenExpired
  TokenActive(email: String)
}

pub type ConsumeError {
  Invalid
  Used
  PasswordError
  DbError(pog.QueryError)
}

pub fn new_reset_token() -> String {
  "pr_"
  <> {
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  }
}

pub fn invalidate_active_for_email(
  db: pog.Connection,
  email: String,
) -> Result(Nil, pog.QueryError) {
  pog.query(
    "update password_resets set invalidated_at = now() where email = $1 and used_at is null and invalidated_at is null",
  )
  |> pog.parameter(pog.text(email))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

pub fn insert_reset(
  db: pog.Connection,
  email: String,
  token: String,
) -> Result(Nil, pog.QueryError) {
  pog.query("insert into password_resets (token, email) values ($1, $2)")
  |> pog.parameter(pog.text(token))
  |> pog.parameter(pog.text(email))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

pub fn user_exists(
  db: pog.Connection,
  email: String,
) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use exists <- decode.field(0, decode.bool)
    decode.success(exists)
  }

  use returned <- result.try(
    pog.query("select exists(select 1 from users where email = $1)")
    |> pog.parameter(pog.text(email))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [exists, ..] -> Ok(exists)
    _ -> Ok(False)
  }
}

pub fn token_status(
  db: pog.Connection,
  token: String,
) -> Result(TokenStatus, pog.QueryError) {
  token_status_internal(db, token, False)
}

pub fn token_status_for_update(
  db: pog.Connection,
  token: String,
) -> Result(TokenStatus, pog.QueryError) {
  token_status_internal(db, token, True)
}

type TokenRow {
  TokenRow(email: String, used: Bool, invalidated: Bool, expired: Bool)
}

fn token_status_internal(
  db: pog.Connection,
  token: String,
  for_update: Bool,
) -> Result(TokenStatus, pog.QueryError) {
  let decoder = {
    use email <- decode.field(0, decode.string)
    use used <- decode.field(1, decode.bool)
    use invalidated <- decode.field(2, decode.bool)
    use expired <- decode.field(3, decode.bool)
    decode.success(TokenRow(email:, used:, invalidated:, expired:))
  }

  let sql =
    "\nselect\n  email,\n  (used_at is not null) as used,\n  (invalidated_at is not null) as invalidated,\n  (created_at < now() - interval '"
    <> int.to_string(reset_token_ttl_hours)
    <> " hours') as expired\nfrom\n  password_resets\nwhere\n  token = $1\n"
    <> case for_update {
      True -> "for update\n"
      False -> ""
    }

  use returned <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(token))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(TokenMissing)

    [TokenRow(invalidated: True, ..), ..] -> Ok(TokenInvalidated)

    [TokenRow(used: True, ..), ..] -> Ok(TokenUsed)

    [TokenRow(expired: True, ..), ..] -> Ok(TokenExpired)

    [TokenRow(email: email, ..), ..] -> Ok(TokenActive(email: email))
  }
}

pub fn mark_used(
  db: pog.Connection,
  token: String,
) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.int)
    decode.success(ok)
  }

  use returned <- result.try(
    pog.query(
      "update password_resets set used_at = now() where token = $1 and used_at is null and invalidated_at is null returning 1",
    )
    |> pog.parameter(pog.text(token))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(False)
    _ -> Ok(True)
  }
}

pub fn update_user_password_hash(
  db: pog.Connection,
  email: String,
  password_hash: String,
) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.int)
    decode.success(ok)
  }

  use returned <- result.try(
    pog.query(
      "update users set password_hash = $2 where email = $1 returning 1",
    )
    |> pog.parameter(pog.text(string.trim(email)))
    |> pog.parameter(pog.text(password_hash))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(False)
    _ -> Ok(True)
  }
}
