//// Database operations for password reset tokens.
////
//// Manages the password reset flow: token generation, validation,
//// and consumption. Tokens expire after 24 hours.

import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/int
import gleam/result
import gleam/string
import pog

/// Token time-to-live in hours.
pub const reset_token_ttl_hours = 24

/// Status of a password reset token.
pub type TokenStatus {
  TokenMissing
  TokenUsed
  TokenInvalidated
  TokenExpired
  TokenActive(email: String)
}

/// Errors that can occur when consuming a reset token.
pub type ConsumeError {
  Invalid
  Used
  PasswordError
  DbError(pog.QueryError)
}

/// Generates a cryptographically secure reset token.
pub fn new_reset_token() -> String {
  "pr_"
  <> {
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  }
}

/// Invalidates all active reset tokens for an email.
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

/// Inserts a new password reset record.
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

/// Checks if a user exists with the given email.
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

/// Gets the status of a reset token.
pub fn token_status(
  db: pog.Connection,
  token: String,
) -> Result(TokenStatus, pog.QueryError) {
  token_status_internal(db, token, False)
}

/// Gets token status with row lock for update.
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

/// Marks a token as used, preventing reuse.
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

/// Updates a user's password hash by email.
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
