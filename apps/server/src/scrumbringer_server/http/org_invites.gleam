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
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/org_invites_db
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

/// Default invite expiration (7 days).
const default_expires_in_hours = 168

/// Handles POST /api/org-invites to create a new invite code.
///
/// Requires admin role. Returns the generated invite code with expiration.
/// Example: handle_create(req, ctx)
pub fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use data <- wisp.require_json(req)

  case create_invite(req, ctx, data) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn create_invite(
  req: wisp.Request,
  ctx: auth.Ctx,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(csrf.require_csrf(req))
  use expires_in_hours <- result.try(decode_expires_in_hours(data))
  let auth.Ctx(db: db, ..) = ctx
  use invite <- result.try(create_invite_db(
    db,
    user.org_id,
    user.id,
    expires_in_hours,
  ))

  Ok(api.ok(json.object([#("invite", invite_json(invite))])))
}

fn require_current_user(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  case auth.require_current_user(req, ctx) {
    Ok(user) -> Ok(user)
    Error(_) ->
      Error(api.error(401, "AUTH_REQUIRED", "Authentication required"))
  }
}

fn require_org_admin(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn decode_expires_in_hours(data: dynamic.Dynamic) -> Result(Int, wisp.Response) {
  let decoder = {
    use hours <- decode.optional_field(
      "expires_in_hours",
      default_expires_in_hours,
      decode.int,
    )
    decode.success(hours)
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn create_invite_db(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
  expires_in_hours: Int,
) -> Result(org_invites_db.OrgInvite, wisp.Response) {
  case org_invites_db.create_invite(db, org_id, user_id, expires_in_hours) {
    Ok(invite) -> Ok(invite)
    Error(org_invites_db.ExpiryHoursInvalid) ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "expires_in_hours must be positive",
      ))
    Error(org_invites_db.NoRowReturned) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(org_invites_db.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn invite_json(invite: org_invites_db.OrgInvite) -> json.Json {
  let org_invites_db.OrgInvite(
    code: code,
    created_at: created_at,
    expires_at: expires_at,
  ) = invite

  json.object([
    #("code", json.string(code)),
    #("created_at", json.string(created_at)),
    #("expires_at", json.string(expires_at)),
  ])
}
