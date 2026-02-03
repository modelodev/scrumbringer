//// Database operations for organization invite links.
////
//// ## Mission
////
//// Manages reusable invite links for organization membership.
////
//// ## Responsibilities
////
//// - Generate secure invite link tokens
//// - Validate and consume invite links
//// - Track invite link state (active, used, invalidated)
//// - Support link regeneration by admins
////
//// ## Non-responsibilities
////
//// - HTTP request handling (see `http/org_invite_links.gleam`)
//// - User registration flow (see `persistence/auth/registration.gleam`)
////
//// ## Relationships
////
//// - Uses `sql.gleam` for persistence

import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql

/// State of an invite link token.
pub type InviteLinkState {
  Active
  Used
  Invalidated
}

/// Status returned when looking up a token.
pub type TokenStatus {
  TokenMissing
  TokenUsed
  TokenInvalidated
  TokenActive(org_id: Int, email: String)
}

/// Converts an invite link state to its DB string.
///
/// Example:
///   state_to_string(Active)
pub fn state_to_string(state: InviteLinkState) -> String {
  case state {
    Active -> "active"
    Used -> "used"
    Invalidated -> "invalidated"
  }
}

/// Invite link record returned by persistence.
pub type OrgInviteLink {
  OrgInviteLink(
    email: String,
    token: String,
    state: InviteLinkState,
    created_at: String,
    used_at: Option(String),
    invalidated_at: Option(String),
  )
}

/// Errors returned when upserting an invite link.
pub type UpsertInviteLinkError {
  DbError(pog.QueryError)
  NoRowReturned
}

/// Inserts or updates an invite link for an email.
///
/// Example:
///   upsert_invite_link(db, org_id, user_id, "invitee@example.com")
pub fn upsert_invite_link(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  email: String,
) -> Result(OrgInviteLink, UpsertInviteLinkError) {
  upsert_with_retry(db, org_id, created_by, email, 5)
}

fn upsert_with_retry(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  email: String,
  attempts: Int,
) -> Result(OrgInviteLink, UpsertInviteLinkError) {
  let token = new_invite_link_token()

  case sql.org_invite_links_upsert(db, org_id, email, token, created_by) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(OrgInviteLink(
        email: row.email,
        token: row.token,
        state: parse_state(row.state),
        created_at: row.created_at,
        used_at: option_helpers.string_to_option(row.used_at),
        invalidated_at: option_helpers.string_to_option(row.invalidated_at),
      ))

    Ok(pog.Returned(rows: [], ..)) -> Error(NoRowReturned)

    Error(error) ->
      handle_upsert_error(db, org_id, created_by, email, attempts, error)
  }
}

fn handle_upsert_error(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  email: String,
  attempts: Int,
  error: pog.QueryError,
) -> Result(OrgInviteLink, UpsertInviteLinkError) {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      handle_constraint_retry(
        db,
        org_id,
        created_by,
        email,
        attempts,
        error,
        constraint,
      )
    _ -> Error(DbError(error))
  }
}

fn handle_constraint_retry(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  email: String,
  attempts: Int,
  error: pog.QueryError,
  constraint: String,
) -> Result(OrgInviteLink, UpsertInviteLinkError) {
  case should_retry_token(attempts, constraint) {
    True -> upsert_with_retry(db, org_id, created_by, email, attempts - 1)
    False -> Error(DbError(error))
  }
}

fn should_retry_token(attempts: Int, constraint: String) -> Bool {
  attempts > 0 && string.contains(constraint, "org_invite_links")
}

/// Lists invite links for an organization.
///
/// Example:
///   list_invite_links(db, org_id)
pub fn list_invite_links(
  db: pog.Connection,
  org_id: Int,
) -> Result(List(OrgInviteLink), pog.QueryError) {
  use returned <- result.try(sql.org_invite_links_list(db, org_id))

  returned.rows
  |> list.map(fn(row) {
    OrgInviteLink(
      email: row.email,
      token: row.token,
      state: parse_state(row.state),
      created_at: row.created_at,
      used_at: option_helpers.string_to_option(row.used_at),
      invalidated_at: option_helpers.string_to_option(row.invalidated_at),
    )
  })
  |> Ok
}

/// Builds the URL path for a token.
///
/// Example:
///   url_path(token)
pub fn url_path(token: String) -> String {
  "/accept-invite?token=" <> token
}

fn parse_state(raw: String) -> InviteLinkState {
  case raw {
    "used" -> Used
    "invalidated" -> Invalidated
    _ -> Active
  }
}

fn new_invite_link_token() -> String {
  "il_"
  <> {
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  }
}

type TokenRow {
  TokenRow(org_id: Int, email: String, used: Bool, invalidated: Bool)
}

/// Fetches the current status for a token.
///
/// Example:
///   token_status(db, token)
pub fn token_status(
  db: pog.Connection,
  token: String,
) -> Result(TokenStatus, pog.QueryError) {
  token_status_internal(db, token, False)
}

/// Fetches the status for a token with row lock.
///
/// Example:
///   token_status_for_update(db, token)
pub fn token_status_for_update(
  db: pog.Connection,
  token: String,
) -> Result(TokenStatus, pog.QueryError) {
  token_status_internal(db, token, True)
}

fn token_status_internal(
  db: pog.Connection,
  token: String,
  for_update: Bool,
) -> Result(TokenStatus, pog.QueryError) {
  let decoder = {
    use org_id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use used <- decode.field(2, decode.bool)
    use invalidated <- decode.field(3, decode.bool)
    decode.success(TokenRow(org_id:, email:, used:, invalidated:))
  }

  let sql =
    "\nselect\n  org_id,\n  email,\n  (used_at is not null) as used,\n  (invalidated_at is not null) as invalidated\nfrom\n  org_invite_links\nwhere\n  token = $1\n"
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

    [TokenRow(org_id: org_id, email: email, ..), ..] ->
      Ok(TokenActive(org_id: org_id, email: email))
  }
}

/// Marks a token as used by a user.
///
/// Example:
///   mark_token_used(db, token, user_id)
pub fn mark_token_used(
  db: pog.Connection,
  token: String,
  used_by: Int,
) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.int)
    decode.success(ok)
  }

  use returned <- result.try(
    pog.query(
      "update org_invite_links set used_at = now(), used_by = $2 where token = $1 and used_at is null and invalidated_at is null returning 1",
    )
    |> pog.parameter(pog.text(token))
    |> pog.parameter(pog.int(used_by))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(False)
    _ -> Ok(True)
  }
}
