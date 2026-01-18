//// User login operations.
////
//// ## Mission
////
//// Handles user authentication including password verification
//// and user lookup.
////
//// ## Responsibilities
////
//// - Authenticate user by email and password
//// - Look up user by ID
//// - Update first login timestamp
////
//// ## Relations
////
//// - **queries.gleam**: Database operations
//// - **auth_logic.gleam**: Error types

import gleam/option.{None, Some}
import gleam/result
import pog
import scrumbringer_server/persistence/auth/queries
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/password
import scrumbringer_server/services/store_state.{type StoredUser}

// =============================================================================
// Public API
// =============================================================================

/// Authenticate user by email and password.
pub fn login(
  db: pog.Connection,
  email: String,
  password_raw: String,
) -> Result(StoredUser, auth_logic.AuthError) {
  use maybe_row <- result.try(
    queries.find_user_by_email(db, email)
    |> result.map_error(auth_logic.DbError),
  )

  use row <- result.try(case maybe_row {
    Some(row) -> Ok(row)
    None -> Error(auth_logic.InvalidCredentials)
  })

  use user <- result.try(queries.user_from_row(row))

  use matched <- result.try(
    password.verify(password_raw, user.password_hash)
    |> result.map_error(auth_logic.PasswordError),
  )

  case matched {
    True -> {
      use _ <- result.try(
        queries.set_first_login_at_if_missing(db, user.id)
        |> result.map_error(auth_logic.DbError),
      )

      Ok(user)
    }

    False -> Error(auth_logic.InvalidCredentials)
  }
}

/// Get user by ID.
pub fn get_user(db: pog.Connection, user_id: Int) -> Result(StoredUser, Nil) {
  case queries.find_user_by_id(db, user_id) {
    Ok(Some(row)) -> queries.user_from_row(row) |> result.replace_error(Nil)
    _ -> Error(Nil)
  }
}
