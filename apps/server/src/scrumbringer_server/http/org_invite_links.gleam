//// HTTP handlers for organization invite links management.
////
//// Provides endpoints for listing and creating/regenerating invite links.
//// Admin-only operations requiring CSRF protection.

import domain/org_role
import gleam/http
import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/org_invite_links/payloads as invite_link_payloads
import scrumbringer_server/http/org_invite_links/presenters as invite_link_presenters
import scrumbringer_server/use_case/org_invite_links_db
import scrumbringer_server/use_case/store_state.{type StoredUser}
import wisp

fn require_admin_context(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(require_admin(user))
  Ok(user)
}

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

/// Handles POST /api/org/invite-links/invalidate to invalidate a link.
pub fn handle_invalidate(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_admin_context(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> invalidate_as_admin(req, ctx, user.org_id)
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case require_admin_context(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> list_invite_links(ctx, user.org_id)
  }
}

fn handle_upsert(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_admin_context(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> upsert_as_admin(req, ctx, user.id, user.org_id)
  }
}

fn list_invite_links(ctx: auth.Ctx, org_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case org_invite_links_db.list_invite_links(db, org_id) {
    Ok(links) -> api.ok(invite_link_presenters.links_response(links))
    Error(error) -> invite_link_error_to_response(error)
  }
}

fn upsert_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: Int,
  org_id: Int,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> upsert_with_csrf(req, ctx, user_id, org_id)
  }
}

fn invalidate_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> invalidate_with_csrf(req, ctx, org_id)
  }
}

fn upsert_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: Int,
  org_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_email_payload(data) {
    Error(resp) -> resp
    Ok(invite_link_payloads.EmailPayload(email: email)) ->
      upsert_invite_link(ctx, org_id, user_id, email)
  }
}

fn invalidate_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_email_payload(data) {
    Error(resp) -> resp
    Ok(invite_link_payloads.EmailPayload(email: email)) ->
      invalidate_invite_link(ctx, org_id, email)
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
    Ok(link) -> api.ok(invite_link_presenters.link_response(link))
    Error(error) -> invite_link_error_to_response(error)
  }
}

fn invalidate_invite_link(
  ctx: auth.Ctx,
  org_id: Int,
  email: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case org_invite_links_db.invalidate_invite_link(db, org_id, email) {
    Ok(link) -> api.ok(invite_link_presenters.link_response(link))
    Error(error) -> invite_link_error_to_response(error)
  }
}

fn invite_link_error_to_response(
  error: org_invite_links_db.InviteLinkError,
) -> wisp.Response {
  case error {
    org_invite_links_db.DbError(_) ->
      api.error(500, "INTERNAL", "Database error")
    org_invite_links_db.InvalidLifecycle(_) ->
      api.error(500, "INTERNAL", "Invalid persisted invite link")
    org_invite_links_db.NotFound ->
      api.error(404, "NOT_FOUND", "Invite link not found")
  }
}

fn require_admin(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn decode_email_payload(
  data,
) -> Result(invite_link_payloads.EmailPayload, wisp.Response) {
  invite_link_payloads.decode_email(data)
  |> result.map_error(invite_link_payload_error_to_response)
}

fn invite_link_payload_error_to_response(
  error: invite_link_payloads.DecodeError,
) -> wisp.Response {
  case error {
    invite_link_payloads.InvalidJson ->
      api.error(400, "VALIDATION_ERROR", "Invalid JSON")
    invite_link_payloads.InvalidEmail ->
      api.error(422, "VALIDATION_ERROR", "Invalid email")
  }
}
