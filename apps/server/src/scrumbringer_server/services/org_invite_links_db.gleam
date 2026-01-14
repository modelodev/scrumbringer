import gleam/bit_array
import gleam/crypto
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/sql

pub type InviteLinkState {
  Active
  Used
  Invalidated
}

pub fn state_to_string(state: InviteLinkState) -> String {
  case state {
    Active -> "active"
    Used -> "used"
    Invalidated -> "invalidated"
  }
}

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

pub type UpsertInviteLinkError {
  DbError(pog.QueryError)
  NoRowReturned
}

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
        used_at: string_option(row.used_at),
        invalidated_at: string_option(row.invalidated_at),
      ))

    Ok(pog.Returned(rows: [], ..)) -> Error(NoRowReturned)

    Error(error) ->
      case error {
        pog.ConstraintViolated(constraint: constraint, ..) ->
          case attempts > 0 && string.contains(constraint, "org_invite_links") {
            True ->
              upsert_with_retry(db, org_id, created_by, email, attempts - 1)
            False -> Error(DbError(error))
          }

        _ -> Error(DbError(error))
      }
  }
}

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
      used_at: string_option(row.used_at),
      invalidated_at: string_option(row.invalidated_at),
    )
  })
  |> Ok
}

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

fn string_option(value: String) -> Option(String) {
  case value {
    "" -> None
    v -> Some(v)
  }
}

fn new_invite_link_token() -> String {
  "il_"
  <> {
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  }
}
