//// HTTP handlers for API tokens.

import domain/org_role
import gleam/http
import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/api_tokens/payloads
import scrumbringer_server/http/api_tokens/presenters
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/services/api_tokens
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

pub fn handle_api_tokens(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    http.Post -> handle_create(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_api_token(
  req: wisp.Request,
  ctx: auth.Ctx,
  token_id: String,
) -> wisp.Response {
  case req.method {
    http.Delete -> handle_revoke(req, ctx, token_id)
    _ -> wisp.method_not_allowed([http.Delete])
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case require_admin(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case api_tokens.list_for_org(db, user.org_id) {
        Ok(tokens) -> api.ok(presenters.tokens_response(tokens))
        Error(error) -> api_token_error_response(error)
      }
    }
  }
}

fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case require_admin_write(req, ctx) {
    Error(resp) -> resp
    Ok(user) ->
      json_payload.with_response(req, decode_create_payload, fn(payload) {
        create_token(ctx, user, payload)
      })
  }
}

fn handle_revoke(
  req: wisp.Request,
  ctx: auth.Ctx,
  token_id: String,
) -> wisp.Response {
  case require_admin_write(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      case api.parse_id(token_id) {
        Error(resp) -> resp
        Ok(token_id) -> revoke_token(ctx, user, token_id)
      }
    }
  }
}

fn create_token(
  ctx: auth.Ctx,
  user: StoredUser,
  payload: payloads.CreateApiTokenPayload,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx
  let payloads.CreateApiTokenPayload(
    name: name,
    integration: integration,
    project_id: project_id,
    scopes: scopes,
    expires_at: expires_at,
  ) = payload

  case
    api_tokens.create_for_integration(
      db,
      user.org_id,
      integration,
      project_id,
      user.id,
      name,
      scopes,
      expires_at,
    )
  {
    Ok(created) -> api.ok(presenters.created_token_response(created))
    Error(error) -> api_token_error_response(error)
  }
}

fn revoke_token(ctx: auth.Ctx, user: StoredUser, token_id: Int) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case api_tokens.revoke(db, user.org_id, token_id) {
    Ok(Nil) -> api.no_content()
    Error(error) -> api_token_error_response(error)
  }
}

fn require_admin_write(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  use user <- result.try(require_admin(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  Ok(user)
}

fn require_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))

  case user.org_role {
    org_role.Admin -> Ok(user)
    org_role.Member -> Error(api.error(403, "FORBIDDEN", "Admin role required"))
  }
}

fn decode_create_payload(data) {
  payloads.decode_create(data)
  |> result.map_error(fn(error) {
    case error {
      payloads.InvalidJson ->
        api.error(422, "VALIDATION_ERROR", "Invalid JSON body")
      payloads.InvalidScope(_) ->
        api.error(422, "VALIDATION_ERROR", "Invalid scope")
    }
  })
}

fn api_token_error_response(error: api_tokens.ApiTokenError) -> wisp.Response {
  case error {
    api_tokens.NameRequired ->
      api.error(422, "VALIDATION_ERROR", "name is required")
    api_tokens.EmptyScopes ->
      api.error(422, "VALIDATION_ERROR", "At least one scope is required")
    api_tokens.IntegrationUserRequired ->
      api.error(422, "VALIDATION_ERROR", "integration is required")
    api_tokens.IntegrationUserNotFound ->
      api.error(404, "NOT_FOUND", "Integration user not found")
    api_tokens.IntegrationUnavailable ->
      api.error(422, "VALIDATION_ERROR", "Integration is not available")
    api_tokens.ProjectNotFound -> api.error(404, "NOT_FOUND", "Project not found")
    api_tokens.ProjectAccessRequired ->
      api.error(403, "FORBIDDEN", "Integration user cannot access project")
    api_tokens.InvalidExpiresAt ->
      api.error(422, "VALIDATION_ERROR", "expires_at must be RFC3339")
    api_tokens.TokenNotFound -> api.error(404, "NOT_FOUND", "Token not found")
    api_tokens.InvalidScope(_) ->
      api.error(422, "VALIDATION_ERROR", "Invalid scope")
    api_tokens.InvalidBearer | api_tokens.TokenExpired | api_tokens.TokenRevoked ->
      api.error(401, "AUTH_REQUIRED", "Invalid token")
    api_tokens.DbError(_) -> api.error(500, "INTERNAL", "Database error")
  }
}
