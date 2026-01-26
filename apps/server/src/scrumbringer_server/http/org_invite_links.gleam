//// HTTP handlers for organization invite links management.
////
//// Provides endpoints for listing and creating/regenerating invite links.
//// Admin-only operations requiring CSRF protection.

import domain/org_role
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/string
import helpers/json as json_helpers
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/org_invite_links_db
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

/// Routes /api/org/invite-links requests (GET list, POST upsert).
///
/// ## Example
///
/// ```gleam
/// handle_invite_links(req, ctx)
/// // GET -> list all invite links for org
/// // POST -> create or regenerate invite link
/// ```
pub fn handle_invite_links(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    http.Post -> handle_upsert(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handles POST /api/org/invite-links/regenerate to regenerate a link.
///
/// Example:
///   handle_regenerate(req, ctx)
pub fn handle_regenerate(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  handle_upsert(req, ctx)
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> list_for_user(ctx, user)
  }
}

fn handle_upsert(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> upsert_for_user(req, ctx, user)
  }
}

fn list_for_user(ctx: auth.Ctx, user: StoredUser) -> wisp.Response {
  case require_admin(user) {
    Error(resp) -> resp
    Ok(Nil) -> list_invite_links(ctx, user.org_id)
  }
}

fn list_invite_links(ctx: auth.Ctx, org_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case org_invite_links_db.list_invite_links(db, org_id) {
    Ok(links) ->
      api.ok(
        json.object([
          #("invite_links", json.array(links, of: invite_link_json)),
        ]),
      )
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn upsert_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
) -> wisp.Response {
  case require_admin(user) {
    Error(resp) -> resp
    Ok(Nil) -> upsert_as_admin(req, ctx, user.id, user.org_id)
  }
}

fn upsert_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: Int,
  org_id: Int,
) -> wisp.Response {
  case require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> upsert_with_csrf(req, ctx, user_id, org_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn upsert_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: Int,
  org_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_email_payload(data) {
    Error(resp) -> resp

    Ok(email_raw) -> {
      let email = normalize_email(email_raw)

      // Justification: nested case validates email before persistence.
      case validate_email(email) {
        Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid email")
        Ok(Nil) -> upsert_invite_link(ctx, org_id, user_id, email)
      }
    }
  }
}

fn upsert_invite_link(
  ctx: auth.Ctx,
  org_id: Int,
  user_id: Int,
  email: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case org_invite_links_db.upsert_invite_link(db, org_id, user_id, email) {
    Ok(link) -> api.ok(json.object([#("invite_link", invite_link_json(link))]))

    Error(org_invite_links_db.NoRowReturned) ->
      api.error(500, "INTERNAL", "Database error")

    Error(org_invite_links_db.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
  }
}

fn require_admin(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn normalize_email(email: String) -> String {
  email
  |> string.trim
  |> string.lowercase
}

fn validate_email(email: String) -> Result(Nil, Nil) {
  case string.split_once(email, "@") {
    Error(_) -> Error(Nil)
    Ok(#(local, domain)) -> validate_email_parts(local, domain)
  }
}

fn validate_email_parts(local: String, domain: String) -> Result(Nil, Nil) {
  case local == "" || domain == "" {
    True -> Error(Nil)
    False -> validate_domain(domain)
  }
}

fn validate_domain(domain: String) -> Result(Nil, Nil) {
  case string.contains(domain, ".") {
    True -> Ok(Nil)
    False -> Error(Nil)
  }
}

fn decode_email_payload(data: dynamic.Dynamic) -> Result(String, wisp.Response) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    decode.success(email)
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(email) -> Ok(email)
  }
}

fn require_csrf(req: wisp.Request) -> Result(Nil, wisp.Response) {
  case csrf.require_double_submit(req) {
    Ok(Nil) -> Ok(Nil)
    Error(_) ->
      Error(api.error(403, "FORBIDDEN", "CSRF token missing or invalid"))
  }
}

fn invite_link_json(link: org_invite_links_db.OrgInviteLink) -> json.Json {
  let org_invite_links_db.OrgInviteLink(
    email: email,
    token: token,
    state: state,
    created_at: created_at,
    used_at: used_at,
    invalidated_at: invalidated_at,
  ) = link

  json.object([
    #("email", json.string(email)),
    #("token", json.string(token)),
    #("url_path", json.string(org_invite_links_db.url_path(token))),
    #("state", json.string(org_invite_links_db.state_to_string(state))),
    #("created_at", json.string(created_at)),
    #("used_at", json_helpers.option_string_json(used_at)),
    #("invalidated_at", json_helpers.option_string_json(invalidated_at)),
  ])
}
