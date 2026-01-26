//// Database operations for organization invite codes.
////
//// Invite codes allow existing organization members to invite new users.
//// Codes are cryptographically random and have configurable expiration.

import gleam/bit_array
import gleam/crypto
import gleam/string
import pog
import scrumbringer_server/sql

/// An invitation code for joining an organization.
pub type OrgInvite {
  OrgInvite(code: String, created_at: String, expires_at: String)
}

/// Errors that can occur when creating an invite.
pub type CreateInviteError {
  DbError(pog.QueryError)
  ExpiryHoursInvalid
  NoRowReturned
}

/// Creates a new organization invite code.
///
/// Generates a cryptographically secure code with the specified expiration.
/// Retries on collision (up to 5 attempts).
///
/// ## Example
/// ```gleam
/// case org_invites_db.create_invite(db, org_id, user_id, 24) {
///   Ok(invite) -> Ok(invite.code)
///   Error(ExpiryHoursInvalid) -> Error(InvalidExpiry)
///   Error(_) -> Error(InternalError)
/// }
/// ```
pub fn create_invite(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  expires_in_hours: Int,
) -> Result(OrgInvite, CreateInviteError) {
  case expires_in_hours > 0 {
    True -> create_with_retry(db, org_id, created_by, expires_in_hours, 5)
    False -> Error(ExpiryHoursInvalid)
  }
}

fn create_with_retry(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  expires_in_hours: Int,
  attempts: Int,
) -> Result(OrgInvite, CreateInviteError) {
  let code = new_invite_code()

  case sql.org_invites(db, code, org_id, created_by, expires_in_hours) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(OrgInvite(
        code: row.code,
        created_at: row.created_at,
        expires_at: row.expires_at,
      ))

    Ok(pog.Returned(rows: [], ..)) -> Error(NoRowReturned)

    Error(error) ->
      handle_create_error(
        error,
        db,
        org_id,
        created_by,
        expires_in_hours,
        attempts,
      )
  }
}

// Justification: nested case improves clarity for branching logic.
fn handle_create_error(
  error: pog.QueryError,
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  expires_in_hours: Int,
  attempts: Int,
) -> Result(OrgInvite, CreateInviteError) {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      // Justification: nested case retries on token uniqueness violations.
      case attempts > 0 && string.contains(constraint, "org_invites") {
        True ->
          create_with_retry(
            db,
            org_id,
            created_by,
            expires_in_hours,
            attempts - 1,
          )
        False -> Error(DbError(error))
      }

    _ -> Error(DbError(error))
  }
}

fn new_invite_code() -> String {
  "inv_"
  <> {
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  }
}
