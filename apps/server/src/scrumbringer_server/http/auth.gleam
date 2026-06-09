//// HTTP handlers for authentication.
////
//// ## Mission
////
//// Provides HTTP endpoints for user authentication: register, login, logout, me.
////
//// ## Responsibilities
////
//// - User registration with invite token validation
//// - Login with JWT issuance
//// - Logout with cookie clearing
//// - Current user endpoint
//// - Invite link validation
////
//// ## Non-responsibilities
////
//// - Password hashing (see `services/password.gleam`)
//// - JWT operations (see `services/jwt.gleam`)
//// - Database operations (see `persistence/auth/`)

import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/http/request
import gleam/list
import gleam/option as opt
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth/payloads as auth_payloads
import scrumbringer_server/http/auth/presenters as auth_presenters
import scrumbringer_server/http/client_ip
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/persistence/auth/login as auth_login
import scrumbringer_server/persistence/auth/registration as auth_registration
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/jwt
import scrumbringer_server/services/org_invite_links_db
import scrumbringer_server/services/rate_limit
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/time
import wisp

/// Context shared by auth HTTP handlers (DB + JWT secret).
pub type Ctx {
  Ctx(db: pog.Connection, jwt_secret: BitArray)
}

const invite_rate_limit_window_seconds = 60

const invite_rate_limit_limit = 30

fn invite_rate_limit_key(
  prefix: String,
  req: wisp.Request,
) -> opt.Option(String) {
  client_ip.from_request(req)
  |> opt.map(fn(ip) { prefix <> ":" <> ip })
}

fn invite_rate_limit_ok(prefix: String, req: wisp.Request) -> Bool {
  case invite_rate_limit_key(prefix, req) {
    opt.None -> True

    opt.Some(key) ->
      rate_limit.allow(
        key,
        invite_rate_limit_limit,
        invite_rate_limit_window_seconds,
        time.now_unix_seconds(),
      )
  }
}

fn require_invite_rate_limit(
  prefix: String,
  req: wisp.Request,
) -> Result(Nil, wisp.Response) {
  case invite_rate_limit_ok(prefix, req) {
    True -> Ok(Nil)
    False -> Error(api.error(429, "RATE_LIMITED", "Too many attempts"))
  }
}

/// Registers a new user via the public API.
///
/// Example:
///   handle_register(req, ctx)
pub fn handle_register(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_invite_rate_limit("register_invite", req) {
    Error(resp) -> resp
    Ok(Nil) -> register_with_payload(req, ctx)
  }
}

fn register_with_payload(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  json_payload.with_response(req, decode_registration_payload, fn(payload) {
    register_valid_payload(ctx, payload)
  })
}

fn register_valid_payload(
  ctx: Ctx,
  payload: auth_payloads.RegistrationPayload,
) -> wisp.Response {
  let Ctx(db: db, jwt_secret: jwt_secret) = ctx

  let now_iso = time.now_iso8601()
  let now_unix = time.now_unix_seconds()

  case
    auth_registration.register(
      db,
      payload.email,
      payload.password,
      payload.org_name,
      payload.invite_token,
      now_iso,
      now_unix,
    )
  {
    Ok(user) -> ok_with_auth(user, jwt_secret)
    Error(error) -> auth_error_response(error)
  }
}

/// Validates an invite link token and returns the associated email if valid.
///
/// Example:
///   handle_invite_link_validate(req, ctx, token)
pub fn handle_invite_link_validate(
  req: wisp.Request,
  ctx: Ctx,
  token: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case require_invite_rate_limit("invite_links", req) {
    Error(resp) -> resp
    Ok(Nil) -> invite_link_status(ctx, token)
  }
}

fn invite_link_status(ctx: Ctx, token: String) -> wisp.Response {
  let Ctx(db: db, ..) = ctx

  case org_invite_links_db.token_status(db, token) {
    Error(_) -> api.error(500, "INTERNAL", "Database error")

    Ok(org_invite_links_db.TokenMissing) ->
      api.error(403, "INVITE_INVALID", "Invite token invalid")

    Ok(org_invite_links_db.TokenInvalidated) ->
      api.error(403, "INVITE_INVALID", "Invite token invalid")

    Ok(org_invite_links_db.TokenUsed) ->
      api.error(403, "INVITE_USED", "Invite token already used")

    Ok(org_invite_links_db.TokenActive(email: email, ..)) ->
      api.ok(auth_presenters.token_email(email))
  }
}

/// Authenticates a user and sets session cookies.
///
/// Example:
///   handle_login(req, ctx)
pub fn handle_login(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  json_payload.with_response(req, decode_login_payload, fn(payload) {
    let auth_payloads.LoginPayload(email: email, password: password) = payload
    login_with_credentials(ctx, email, password)
  })
}

fn login_with_credentials(
  ctx: Ctx,
  email: String,
  password: String,
) -> wisp.Response {
  let Ctx(db: db, jwt_secret: jwt_secret) = ctx

  case auth_login.login(db, email, password) {
    Ok(user) -> ok_with_auth(user, jwt_secret)
    Error(_) -> api.error(403, "FORBIDDEN", "Invalid credentials")
  }
}

/// Returns the current authenticated user.
///
/// Example:
///   handle_me(req, ctx)
pub fn handle_me(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case require_current_user(req, ctx) {
    Ok(user) -> api.ok(auth_presenters.user_response(user))
    Error(_) -> auth_required_response()
  }
}

/// Clears auth cookies and ends the session.
///
/// Example:
///   handle_logout(req, ctx)
pub fn handle_logout(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_current_user(req, ctx) {
    Error(_) -> auth_required_response()

    Ok(_user) -> logout_with_csrf(req)
  }
}

fn logout_with_csrf(req: wisp.Request) -> wisp.Response {
  case csrf.require_csrf(req) {
    Ok(Nil) ->
      api.no_content()
      |> api.clear_auth_cookies

    Error(resp) -> resp
  }
}

fn ok_with_auth(user: StoredUser, jwt_secret: BitArray) -> wisp.Response {
  let session_jwt =
    jwt.new_claims(user.id, user.org_id, user.org_role)
    |> jwt.sign(jwt_secret)

  let csrf = new_csrf_token()

  api.ok(auth_presenters.user_response(user))
  |> api.set_auth_cookies(session_jwt, csrf)
}

/// Extracts the current user or returns an auth error.
///
/// Example:
///   case require_current_user(req, ctx) { Ok(user) -> user, Error(_) -> fallback }
pub fn require_current_user(
  req: wisp.Request,
  ctx: Ctx,
) -> Result(StoredUser, Nil) {
  let Ctx(db: db, jwt_secret: jwt_secret) = ctx

  use token <- result.try(get_cookie(req, api.cookie_session_name))

  use claims <- result.try(
    jwt.verify(token, jwt_secret)
    |> result.replace_error(Nil),
  )

  auth_login.get_user(db, claims.user_id)
}

pub fn require_current_user_response(
  req: wisp.Request,
  ctx: Ctx,
) -> Result(StoredUser, wisp.Response) {
  require_current_user(req, ctx)
  |> result.map_error(fn(_) { auth_required_response() })
}

pub fn auth_required_response() -> wisp.Response {
  api.error(401, "AUTH_REQUIRED", "Authentication required")
}

fn get_cookie(req: wisp.Request, name: String) -> Result(String, Nil) {
  req
  |> request.get_cookies
  |> list.key_find(name)
}

fn auth_error_response(error: auth_logic.AuthError) -> wisp.Response {
  case error {
    auth_logic.InviteRequired ->
      api.error(403, "INVITE_REQUIRED", "Invite token required")
    auth_logic.InviteInvalid ->
      api.error(403, "INVITE_INVALID", "Invite token invalid")
    auth_logic.InviteExpired ->
      api.error(403, "INVITE_EXPIRED", "Invite token expired")
    auth_logic.InviteUsed ->
      api.error(403, "INVITE_USED", "Invite token already used")
    auth_logic.OrgNameRequired ->
      api.error(422, "VALIDATION_ERROR", "org_name is required")
    auth_logic.EmailTaken ->
      api.error(422, "VALIDATION_ERROR", "Email already taken")
    auth_logic.PasswordError(_) ->
      api.error(500, "INTERNAL", "Password hashing failed")
    auth_logic.DbError(_) -> api.error(500, "INTERNAL", "Database error")
    auth_logic.InvalidCredentials ->
      api.error(422, "VALIDATION_ERROR", "Invalid registration")
  }
}

fn new_csrf_token() -> String {
  crypto.strong_random_bytes(32)
  |> bit_array.base64_url_encode(False)
}

fn decode_registration_payload(
  data,
) -> Result(auth_payloads.RegistrationPayload, wisp.Response) {
  auth_payloads.decode_registration(data)
  |> result.map_error(payload_error_to_response)
}

fn decode_login_payload(
  data,
) -> Result(auth_payloads.LoginPayload, wisp.Response) {
  auth_payloads.decode_login(data)
  |> result.map_error(payload_error_to_response)
}

fn payload_error_to_response(error: auth_payloads.DecodeError) -> wisp.Response {
  case error {
    auth_payloads.InvalidJson ->
      api.error(400, "VALIDATION_ERROR", "Invalid JSON")
    auth_payloads.PasswordTooShort ->
      api.error(
        422,
        "VALIDATION_ERROR",
        "Password must be at least 12 characters",
      )
  }
}
