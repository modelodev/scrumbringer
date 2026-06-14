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
import gleam/option as gleam_option
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/services/persisted_field
import scrumbringer_server/sql

/// Lifecycle state of an invite link token with timestamps.
pub type InviteLinkLifecycle {
  Active(created_at: String)
  Used(created_at: String, used_at: String)
  Invalidated(created_at: String, invalidated_at: String)
}

/// Status returned when looking up a token.
pub type TokenStatus {
  TokenMissing
  TokenUsed
  TokenInvalidated
  TokenActive(org_id: Int, email: String)
}

/// Converts an invite link lifecycle to its string state.
///
/// Example:
///   lifecycle_state_to_string(Active("2024-01-01T00:00:00Z"))
pub fn lifecycle_state_to_string(lifecycle: InviteLinkLifecycle) -> String {
  case lifecycle {
    Active(..) -> "active"
    Used(..) -> "used"
    Invalidated(..) -> "invalidated"
  }
}

/// Returns the creation timestamp from the invite lifecycle.
pub fn lifecycle_created_at(lifecycle: InviteLinkLifecycle) -> String {
  case lifecycle {
    Active(created_at) -> created_at
    Used(created_at, ..) -> created_at
    Invalidated(created_at, ..) -> created_at
  }
}

/// Returns the used timestamp when the invite was consumed.
pub fn lifecycle_used_at(
  lifecycle: InviteLinkLifecycle,
) -> gleam_option.Option(String) {
  case lifecycle {
    Used(_, used_at) -> gleam_option.Some(used_at)
    _ -> gleam_option.None
  }
}

/// Returns the invalidated timestamp when the invite was revoked.
pub fn lifecycle_invalidated_at(
  lifecycle: InviteLinkLifecycle,
) -> gleam_option.Option(String) {
  case lifecycle {
    Invalidated(_, invalidated_at) -> gleam_option.Some(invalidated_at)
    _ -> gleam_option.None
  }
}

/// Invite link record returned by persistence.
pub type OrgInviteLink {
  OrgInviteLink(email: String, token: String, lifecycle: InviteLinkLifecycle)
}

/// Invalid persisted lifecycle shapes.
pub type InviteLinkDataError {
  UnknownLifecycleState(String)
  UsedWithoutUsedAt
  InvalidatedWithoutInvalidatedAt
}

/// Errors returned by invite link persistence.
pub type InviteLinkError {
  DbError(pog.QueryError)
  InvalidLifecycle(InviteLinkDataError)
  NotFound
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
) -> Result(OrgInviteLink, InviteLinkError) {
  upsert_with_retry(db, org_id, created_by, email, 5)
}

fn upsert_with_retry(
  db: pog.Connection,
  org_id: Int,
  created_by: Int,
  email: String,
  attempts: Int,
) -> Result(OrgInviteLink, InviteLinkError) {
  let token = new_invite_link_token()

  case sql.org_invite_links_upsert(db, org_id, email, token, created_by) {
    Ok(pog.Returned(rows: rows, ..)) -> {
      use row <- result.try(
        persisted_field.query_row(rows)
        |> result.map_error(DbError),
      )
      invite_link_from_fields(
        row.email,
        row.token,
        row.state,
        row.created_at,
        row.used_at,
        row.invalidated_at,
      )
    }

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
) -> Result(OrgInviteLink, InviteLinkError) {
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
) -> Result(OrgInviteLink, InviteLinkError) {
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
) -> Result(List(OrgInviteLink), InviteLinkError) {
  use returned <- result.try(
    sql.org_invite_links_list(db, org_id)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.try_map(fn(row) {
    invite_link_from_fields(
      row.email,
      row.token,
      row.state,
      row.created_at,
      row.used_at,
      row.invalidated_at,
    )
  })
}

/// Invalidates an active invite link for an organization and email.
pub fn invalidate_invite_link(
  db: pog.Connection,
  org_id: Int,
  email: String,
) -> Result(OrgInviteLink, InviteLinkError) {
  case sql.org_invite_links_invalidate(db, org_id, email) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      invite_link_from_fields(
        row.email,
        row.token,
        row.state,
        row.created_at,
        row.used_at,
        row.invalidated_at,
      )
  }
}

fn invite_link_from_fields(
  email: String,
  token: String,
  state: String,
  created_at: String,
  used_at: String,
  invalidated_at: String,
) -> Result(OrgInviteLink, InviteLinkError) {
  use lifecycle <- result.try(
    lifecycle_from_db(
      state,
      created_at,
      option_helpers.string_to_option(used_at),
      option_helpers.string_to_option(invalidated_at),
    )
    |> result.map_error(InvalidLifecycle),
  )
  Ok(OrgInviteLink(email: email, token: token, lifecycle: lifecycle))
}

/// Builds the URL path for a token.
///
/// Example:
///   url_path(token)
pub fn url_path(token: String) -> String {
  "/accept-invite?token=" <> token
}

/// Parses persisted lifecycle columns into a consistent typed lifecycle.
pub fn lifecycle_from_db(
  raw: String,
  created_at: String,
  used_at: gleam_option.Option(String),
  invalidated_at: gleam_option.Option(String),
) -> Result(InviteLinkLifecycle, InviteLinkDataError) {
  case raw {
    "active" -> Ok(Active(created_at))
    "used" ->
      case used_at {
        gleam_option.Some(at) -> Ok(Used(created_at, at))
        gleam_option.None -> Error(UsedWithoutUsedAt)
      }
    "invalidated" ->
      case invalidated_at {
        gleam_option.Some(at) -> Ok(Invalidated(created_at, at))
        gleam_option.None -> Error(InvalidatedWithoutInvalidatedAt)
      }
    other -> Error(UnknownLifecycleState(other))
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
  let sql =
    "\nselect\n  org_id,\n  email,\n  (used_at is not null) as used,\n  (invalidated_at is not null) as invalidated\nfrom\n  org_invite_links\nwhere\n  token = $1\n"
    <> case for_update {
      True -> "for update\n"
      False -> ""
    }

  use returned <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(token))
    |> pog.returning(token_row_decoder())
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
  use returned <- result.try(
    pog.query(
      "update org_invite_links set used_at = now(), used_by = $2 where token = $1 and used_at is null and invalidated_at is null returning 1",
    )
    |> pog.parameter(pog.text(token))
    |> pog.parameter(pog.int(used_by))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(False)
    _ -> Ok(True)
  }
}

fn token_row_decoder() -> decode.Decoder(TokenRow) {
  use org_id <- decode.field(0, decode.int)
  use email <- decode.field(1, decode.string)
  use used <- decode.field(2, decode.bool)
  use invalidated <- decode.field(3, decode.bool)
  decode.success(TokenRow(org_id:, email:, used:, invalidated:))
}
