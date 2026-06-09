//// HTTP handlers for organization invite management.
////
//// ## Mission
////
//// Provide admin-only endpoints to generate organization invite codes.
////
//// ## Responsibilities
////
//// - Validate admin access and CSRF tokens
//// - Parse invite expiration input
//// - Create invite codes via the persistence layer
////
//// ## Non-responsibilities
////
//// - Invite persistence (see `services/org_invites_db.gleam`)
//// - Authentication (see `http/auth.gleam`)
////
//// ## Relations
////
//// - Uses `services/org_invites_db` for persistence
//// - Uses `http/auth` and `http/csrf` for auth and CSRF validation

import domain/org_role
import gleam/http
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/org_invites/payloads as invite_payloads
import scrumbringer_server/http/org_invites/presenters as invite_presenters
import scrumbringer_server/services/org_invites_db
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

/// Handles POST /api/org-invites to create a new invite code.
///
/// Requires admin role. Returns the generated invite code with expiration.
/// Example: handle_create(req, ctx)
pub fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_create_access(req, ctx) {
    Error(resp) -> resp
    Ok(#(db, user)) -> {
      use data <- wisp.require_json(req)
      create_invite_from_json(db, user, data)
    }
  }
}

fn require_create_access(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(#(pog.Connection, StoredUser), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(csrf.require_csrf(req))
  let auth.Ctx(db: db, ..) = ctx

  Ok(#(db, user))
}

fn create_invite_from_json(
  db: pog.Connection,
  user: StoredUser,
  data,
) -> wisp.Response {
  case decode_create_invite(data) {
    Error(resp) -> resp
    Ok(payload) ->
      case create_invite(db, user, payload) {
        Ok(resp) -> resp
        Error(resp) -> resp
      }
  }
}

fn create_invite(
  db: pog.Connection,
  user: StoredUser,
  payload: invite_payloads.CreateInvitePayload,
) -> Result(wisp.Response, wisp.Response) {
  use invite <- result.try(create_invite_db(
    db,
    user.org_id,
    user.id,
    payload.expires_in_hours,
  ))

  Ok(api.ok(invite_presenters.invite_response(invite)))
}

fn require_org_admin(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn decode_create_invite(
  data,
) -> Result(invite_payloads.CreateInvitePayload, wisp.Response) {
  invite_payloads.decode_create(data)
  |> result.map_error(invite_payload_error_to_response)
}

fn invite_payload_error_to_response(
  error: invite_payloads.DecodeError,
) -> wisp.Response {
  case error {
    invite_payloads.InvalidJson ->
      api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  }
}

fn create_invite_db(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
  expires_in_hours: Int,
) -> Result(org_invites_db.OrgInvite, wisp.Response) {
  case org_invites_db.create_invite(db, org_id, user_id, expires_in_hours) {
    Ok(invite) -> Ok(invite)
    Error(error) -> Error(create_invite_error_to_response(error))
  }
}

fn create_invite_error_to_response(
  error: org_invites_db.CreateInviteError,
) -> wisp.Response {
  case error {
    org_invites_db.ExpiryHoursInvalid ->
      api.error(422, "VALIDATION_ERROR", "expires_in_hours must be positive")
    org_invites_db.DbError(_) -> api.error(500, "INTERNAL", "Database error")
  }
}
