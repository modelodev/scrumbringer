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

import domain/org_role
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option as opt
import gleam/result
import gleam/string
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/csrf
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

type RegistrationPayload {
  RegistrationPayload(
    email_raw: String,
    password: String,
    org_name_raw: String,
    invite_token_raw: String,
  )
}

fn client_ip(req: wisp.Request) -> opt.Option(String) {
  let xff =
    request.get_header(req, "x-forwarded-for")
    |> result.unwrap("")

  let x_real = request.get_header(req, "x-real-ip") |> result.unwrap("")

  let raw = case xff {
    "" -> x_real
    _ -> xff
  }

  raw
  |> string.split(",")
  |> list.first
  |> result.unwrap("")
  |> string.trim
  |> fn(value) {
    case value {
      "" -> opt.None
      _ -> opt.Some(value)
    }
  }
}

fn invite_rate_limit_key(
  prefix: String,
  req: wisp.Request,
) -> opt.Option(String) {
  client_ip(req)
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

fn empty_to_option(value: String) -> opt.Option(String) {
  case value {
    "" -> opt.None
    _ -> opt.Some(value)
  }
}

fn register_decoder() -> decode.Decoder(RegistrationPayload) {
  use email <- decode.optional_field("email", "", decode.string)
  use password <- decode.field("password", decode.string)
  use org_name <- decode.optional_field("org_name", "", decode.string)
  use invite_token <- decode.optional_field("invite_token", "", decode.string)
  decode.success(RegistrationPayload(
    email_raw: email,
    password: password,
    org_name_raw: org_name,
    invite_token_raw: invite_token,
  ))
}

fn validate_password(password: String) -> Result(Nil, wisp.Response) {
  case string.length(password) < 12 {
    True ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Password must be at least 12 characters",
      ))

    False -> Ok(Nil)
  }
}

/// Registers a new user via the public API.
///
/// Example:
///   handle_register(req, ctx)
pub fn handle_register(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case invite_rate_limit_ok("register_invite", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> register_with_payload(req, ctx)
  }
}

fn register_with_payload(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode.run(data, register_decoder()) {
    Ok(payload) -> register_with_payload_value(ctx, payload)
    Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  }
}

fn register_with_payload_value(
  ctx: Ctx,
  payload: RegistrationPayload,
) -> wisp.Response {
  case validate_password(payload.password) {
    Error(response) -> response
    Ok(Nil) -> register_valid_payload(ctx, payload)
  }
}

fn register_valid_payload(
  ctx: Ctx,
  payload: RegistrationPayload,
) -> wisp.Response {
  let Ctx(db: db, jwt_secret: jwt_secret) = ctx

  let org_name = empty_to_option(payload.org_name_raw)
  let email = empty_to_option(payload.email_raw)
  let invite_token = empty_to_option(payload.invite_token_raw)
  let now_iso = time.now_iso8601()
  let now_unix = time.now_unix_seconds()

  case
    auth_registration.register(
      db,
      email,
      payload.password,
      org_name,
      invite_token,
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

  case invite_rate_limit_ok("invite_links", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")
    True -> invite_link_status(ctx, token)
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
      api.ok(json.object([#("email", json.string(email))]))
  }
}

/// Authenticates a user and sets session cookies.
///
/// Example:
///   handle_login(req, ctx)
pub fn handle_login(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use data <- wisp.require_json(req)

  let decoder = {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(#(email, password))
  }

  case decode.run(data, decoder) {
    Ok(#(email, password)) -> login_with_credentials(ctx, email, password)

    Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  }
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
    Ok(user) -> api.ok(json.object([#("user", user_json(user))]))
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
  }
}

/// Clears auth cookies and ends the session.
///
/// Example:
///   handle_logout(req, ctx)
pub fn handle_logout(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(_user) -> logout_with_csrf(req)
  }
}

fn logout_with_csrf(req: wisp.Request) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Ok(Nil) ->
      api.no_content()
      |> api.clear_auth_cookies

    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
  }
}

fn ok_with_auth(user: StoredUser, jwt_secret: BitArray) -> wisp.Response {
  let session_jwt =
    jwt.new_claims(user.id, user.org_id, user.org_role)
    |> jwt.sign(jwt_secret)

  let csrf = new_csrf_token()

  api.ok(json.object([#("user", user_json(user))]))
  |> api.set_auth_cookies(session_jwt, csrf)
}

/// Extracts the current user or returns an auth error.
///
/// Example:
///   case require_current_user(req, ctx) { Ok(user) -> user, Error(_) -> todo }
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

fn get_cookie(req: wisp.Request, name: String) -> Result(String, Nil) {
  req
  |> request.get_cookies
  |> list.key_find(name)
}

fn user_json(user: StoredUser) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("email", json.string(user.email)),
    #("org_id", json.int(user.org_id)),
    #("org_role", json.string(org_role.to_string(user.org_role))),
    #("created_at", json.string(user.created_at)),
  ])
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
    _ -> api.error(422, "VALIDATION_ERROR", "Invalid registration")
  }
}

fn new_csrf_token() -> String {
  crypto.strong_random_bytes(32)
  |> bit_array.base64_url_encode(False)
}
