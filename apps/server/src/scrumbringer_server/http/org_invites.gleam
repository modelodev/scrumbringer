//// HTTP handlers for organization invite management.
////
//// Provides endpoints for creating invite codes that allow new users
//// to join an organization. Only organization admins can create invites.

import gleam/dynamic/decode
import gleam/http
import gleam/json
import domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/org_invites_db
import wisp

/// Default invite expiration (7 days).
const default_expires_in_hours = 168

/// Handles POST /api/org-invites to create a new invite code.
///
/// Requires admin role. Returns the generated invite code with expiration.
pub fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case user.org_role {
        org_role.Admin -> create_as_admin(req, ctx, user.id, user.org_id)
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
    }
  }
}

fn create_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: Int,
  org_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use hours <- decode.optional_field(
          "expires_in_hours",
          default_expires_in_hours,
          decode.int,
        )
        decode.success(hours)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(expires_in_hours) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            org_invites_db.create_invite(db, org_id, user_id, expires_in_hours)
          {
            Ok(invite) ->
              api.ok(json.object([#("invite", invite_json(invite))]))
            Error(org_invites_db.ExpiryHoursInvalid) ->
              api.error(
                422,
                "VALIDATION_ERROR",
                "expires_in_hours must be positive",
              )
            Error(org_invites_db.NoRowReturned) ->
              api.error(500, "INTERNAL", "Database error")
            Error(org_invites_db.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
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
