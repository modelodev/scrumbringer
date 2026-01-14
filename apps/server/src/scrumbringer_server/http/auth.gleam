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
import scrumbringer_domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/csrf
import scrumbringer_server/services/auth_db
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/jwt
import scrumbringer_server/services/org_invite_links_db
import scrumbringer_server/services/rate_limit
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/time
import wisp

pub type Ctx {
  Ctx(db: pog.Connection, jwt_secret: BitArray)
}

const invite_rate_limit_window_seconds = 60

const invite_rate_limit_limit = 30

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

pub fn handle_register(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case invite_rate_limit_ok("register_invite", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use email <- decode.optional_field("email", "", decode.string)
        use password <- decode.field("password", decode.string)
        use org_name <- decode.optional_field("org_name", "", decode.string)
        use invite_token <- decode.optional_field(
          "invite_token",
          "",
          decode.string,
        )
        decode.success(#(email, password, org_name, invite_token))
      }

      case decode.run(data, decoder) {
        Ok(#(email_raw, password, org_name_raw, invite_token_raw)) -> {
          case string.length(password) < 12 {
            True ->
              api.error(
                422,
                "VALIDATION_ERROR",
                "Password must be at least 12 characters",
              )

            False -> {
              let org_name = case org_name_raw {
                "" -> opt.None
                other -> opt.Some(other)
              }

              let email = case email_raw {
                "" -> opt.None
                other -> opt.Some(other)
              }

              let invite_token = case invite_token_raw {
                "" -> opt.None
                other -> opt.Some(other)
              }

              let now_iso = time.now_iso8601()
              let now_unix = time.now_unix_seconds()

              let Ctx(db: db, jwt_secret: jwt_secret) = ctx

              case
                auth_db.register(
                  db,
                  email,
                  password,
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
          }
        }

        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")
      }
    }
  }
}

pub fn handle_invite_link_validate(
  req: wisp.Request,
  ctx: Ctx,
  token: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case invite_rate_limit_ok("invite_links", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> {
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
  }
}

pub fn handle_login(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use data <- wisp.require_json(req)

  let decoder = {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(#(email, password))
  }

  case decode.run(data, decoder) {
    Ok(#(email, password)) -> {
      let Ctx(db: db, jwt_secret: jwt_secret) = ctx

      case auth_db.login(db, email, password) {
        Ok(user) -> ok_with_auth(user, jwt_secret)
        Error(_) -> api.error(403, "FORBIDDEN", "Invalid credentials")
      }
    }

    Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  }
}

pub fn handle_me(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case require_current_user(req, ctx) {
    Ok(user) -> api.ok(json.object([#("user", user_json(user))]))
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
  }
}

pub fn handle_logout(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(_user) -> {
      case csrf.require_double_submit(req) {
        Ok(Nil) ->
          api.no_content()
          |> api.clear_auth_cookies

        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
      }
    }
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

  auth_db.get_user(db, claims.user_id)
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
