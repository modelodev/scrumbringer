//// HTTP handlers for integration users.

import domain/org_role
import gleam/http
import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/integration_users/payloads
import scrumbringer_server/http/integration_users/presenters
import scrumbringer_server/http/json_payload
import scrumbringer_server/services/integration_users
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

pub fn handle_integration_users(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    http.Post -> handle_create(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case require_admin(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case integration_users.list_for_org(db, user.org_id) {
        Ok(users) -> api.ok(presenters.integration_users_response(users))
        Error(error) -> integration_user_error_response(error)
      }
    }
  }
}

fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case require_admin_write(req, ctx) {
    Error(resp) -> resp
    Ok(user) ->
      json_payload.with_response(req, decode_create_payload, fn(payload) {
        create_integration_user(ctx, user, payload)
      })
  }
}

fn create_integration_user(
  ctx: auth.Ctx,
  user: StoredUser,
  payload: payloads.CreateIntegrationUserPayload,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx
  let payloads.CreateIntegrationUserPayload(email: email) = payload

  case integration_users.create(db, user.org_id, email) {
    Ok(created) -> api.ok(presenters.integration_user_response(created))
    Error(error) -> integration_user_error_response(error)
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
  |> result.map_error(fn(_) {
    api.error(422, "VALIDATION_ERROR", "Invalid JSON body")
  })
}

fn integration_user_error_response(
  error: integration_users.IntegrationUserError,
) -> wisp.Response {
  case error {
    integration_users.EmailRequired ->
      api.error(422, "VALIDATION_ERROR", "email is required")
    integration_users.EmailTaken ->
      api.error(422, "VALIDATION_ERROR", "Email already taken")
    integration_users.NotFound -> api.error(404, "NOT_FOUND", "Not found")
    integration_users.InvalidPersistedRole(_) ->
      api.error(500, "INTERNAL", "Invalid persisted role")
    integration_users.DbError(_) -> api.error(500, "INTERNAL", "Database error")
  }
}
