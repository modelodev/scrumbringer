//// User registration operations.
////
//// ## Mission
////
//// Handles user registration flows including bootstrap registration
//// (first user creates organization) and invite-based registration.
////
//// ## Responsibilities
////
//// - Bootstrap registration (first user + org creation)
//// - Invite-based registration (subsequent users)
//// - Password hashing during registration
////
//// ## Relations
////
//// - **queries.gleam**: Database operations
//// - **auth_logic.gleam**: Error types

import gleam/option.{type Option, Some}
import gleam/result
import pog
import domain/org_role
import scrumbringer_server/persistence/auth/queries
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/org_invite_links_db
import scrumbringer_server/services/password
import scrumbringer_server/services/store_state.{type StoredUser, StoredUser}

// =============================================================================
// Public API
// =============================================================================

/// Register a new user. Routes to bootstrap or invite flow based on org existence.
pub fn register(
  db: pog.Connection,
  email: Option(String),
  password_raw: String,
  org_name: Option(String),
  invite_token: Option(String),
  _now_iso: String,
  _now_unix: Int,
) -> Result(StoredUser, auth_logic.AuthError) {
  use org_exists <- result.try(
    queries.organization_exists(db)
    |> result.map_error(auth_logic.DbError),
  )

  case org_exists {
    True -> invite_register(db, password_raw, invite_token)

    False -> {
      let email = case email {
        Some(e) if e != "" -> Ok(e)
        _ -> Error(auth_logic.InviteInvalid)
      }

      use email <- result.try(email)
      bootstrap_register(db, email, password_raw, org_name)
    }
  }
}

// =============================================================================
// Bootstrap Registration
// =============================================================================

/// Register first user and create organization.
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
      queries.insert_organization(tx, org_name)
      |> result.map_error(auth_logic.DbError),
    )

    use project_id <- result.try(
      queries.insert_default_project(tx, org_id)
      |> result.map_error(auth_logic.DbError),
    )

    use user_row <- result.try(
      queries.insert_user(tx, email, password_hash, org_id, "admin")
      |> result.map_error(queries.map_user_insert_error),
    )

    let #(user_id, created_at) = user_row

    use _ <- result.try(
      queries.insert_project_member(tx, project_id, user_id, "admin")
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
  |> result.map_error(queries.transaction_error_to_auth_error)
}

// =============================================================================
// Invite Registration
// =============================================================================

/// Register user via invite token.
fn invite_register(
  db: pog.Connection,
  password_raw: String,
  invite_token: Option(String),
) -> Result(StoredUser, auth_logic.AuthError) {
  let invite_token = case invite_token {
    Some(token) if token != "" -> Ok(token)
    _ -> Error(auth_logic.InviteRequired)
  }
  use invite_token <- result.try(invite_token)

  use password_hash <- result.try(
    password.hash(password_raw)
    |> result.map_error(auth_logic.PasswordError),
  )

  pog.transaction(db, fn(tx) {
    use status <- result.try(
      org_invite_links_db.token_status_for_update(tx, invite_token)
      |> result.map_error(auth_logic.DbError),
    )

    case status {
      org_invite_links_db.TokenMissing -> Error(auth_logic.InviteInvalid)
      org_invite_links_db.TokenInvalidated -> Error(auth_logic.InviteInvalid)
      org_invite_links_db.TokenUsed -> Error(auth_logic.InviteUsed)

      org_invite_links_db.TokenActive(org_id: org_id, email: email) -> {
        use user_row <- result.try(
          queries.insert_user(tx, email, password_hash, org_id, "member")
          |> result.map_error(queries.map_user_insert_error),
        )

        let #(user_id, created_at) = user_row

        use used <- result.try(
          org_invite_links_db.mark_token_used(tx, invite_token, user_id)
          |> result.map_error(auth_logic.DbError),
        )

        case used {
          True ->
            Ok(StoredUser(
              id: user_id,
              email: email,
              password_hash: password_hash,
              org_id: org_id,
              org_role: org_role.Member,
              created_at: created_at,
            ))

          False -> Error(auth_logic.InviteUsed)
        }
      }
    }
  })
  |> result.map_error(queries.transaction_error_to_auth_error)
}
