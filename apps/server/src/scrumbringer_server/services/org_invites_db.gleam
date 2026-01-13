import gleam/bit_array
import gleam/crypto
import gleam/string
import pog
import scrumbringer_server/sql

pub type OrgInvite {
  OrgInvite(code: String, created_at: String, expires_at: String)
}

pub type CreateInviteError {
  DbError(pog.QueryError)
  ExpiryHoursInvalid
  NoRowReturned
}

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
      case error {
        pog.ConstraintViolated(constraint: constraint, ..) ->
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
}

fn new_invite_code() -> String {
  "inv_"
  <> {
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  }
}
