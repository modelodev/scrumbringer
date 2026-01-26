//// HTTP handlers for password reset flow.
////
//// ## Mission
////
//// Provides HTTP endpoints for password reset: request, validate, and consume.
////
//// ## Responsibilities
////
//// - Create password reset tokens with rate limiting
//// - Validate reset tokens
//// - Consume tokens and update passwords in transaction
////
//// ## Non-responsibilities
////
//// - Token generation (see `services/password_resets_db.gleam`)
//// - Password hashing (see `services/password.gleam`)
////

import gleam/dynamic
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
import scrumbringer_server/services/password
import scrumbringer_server/services/password_resets_db
import scrumbringer_server/services/rate_limit
import scrumbringer_server/services/time
import wisp

/// Context for password reset handlers.
pub type Ctx {
  Ctx(db: pog.Connection)
}

const password_reset_rate_limit_window_seconds = 60

const password_reset_rate_limit_limit = 30

type ConsumeTxError {
  ConsumeInvalidToken
  ConsumeUsedToken
  ConsumePasswordHashError
  ConsumeDbError(pog.QueryError)
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

fn rate_limit_key(prefix: String, req: wisp.Request) -> opt.Option(String) {
  client_ip(req)
  |> opt.map(fn(ip) { prefix <> ":" <> ip })
}

fn rate_limit_ok(prefix: String, req: wisp.Request) -> Bool {
  case rate_limit_key(prefix, req) {
    opt.None -> True

    opt.Some(key) ->
      rate_limit.allow(
        key,
        password_reset_rate_limit_limit,
        password_reset_rate_limit_window_seconds,
        time.now_unix_seconds(),
      )
  }
}

/// Handle POST /api/password-resets to request a reset token.
/// Example:
///   handle_password_resets(req, ctx)
pub fn handle_password_resets(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  case req.method {
    http.Post -> handle_create(req, ctx)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

/// Handle validation for a password reset token.
/// Example:
///   handle_password_reset_token(req, ctx, token)
pub fn handle_password_reset_token(
  req: wisp.Request,
  ctx: Ctx,
  token: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_validate(req, ctx, token)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

/// Consume a password reset token and update the password.
/// Example:
///   handle_consume(req, ctx)
pub fn handle_consume(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  case req.method {
    http.Post -> handle_consume_post(req, ctx)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// Justification: nested case improves clarity for branching logic.
fn handle_create(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case rate_limit_ok("password_resets_request", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> {
      use data <- wisp.require_json(req)
      // Justified nested case: unwrap Result<Response, Response> into a Response.
      case create_reset(ctx, data) {
        Ok(resp) -> resp
        Error(resp) -> resp
      }
    }
  }
}

fn ok_reset_payload(token: String, url_path: String) -> wisp.Response {
  api.ok(
    json.object([
      #(
        "reset",
        json.object([
          #("token", json.string(token)),
          #("url_path", json.string(url_path)),
        ]),
      ),
    ]),
  )
}

// Justification: nested case improves clarity for branching logic.
fn handle_validate(req: wisp.Request, ctx: Ctx, token: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case rate_limit_ok("password_resets_validate", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> {
      let Ctx(db: db) = ctx

      case password_resets_db.token_status(db, token) {
        Error(_) -> api.error(500, "INTERNAL", "Database error")

        Ok(password_resets_db.TokenActive(email: email)) ->
          api.ok(json.object([#("email", json.string(email))]))

        Ok(password_resets_db.TokenUsed) ->
          api.error(403, "RESET_TOKEN_USED", "Reset token already used")

        Ok(_) -> api.error(403, "RESET_TOKEN_INVALID", "Reset token invalid")
      }
    }
  }
}

// Justification: nested case improves clarity for branching logic.
fn handle_consume_post(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case rate_limit_ok("password_resets_consume", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> {
      use data <- wisp.require_json(req)
      // Justified nested case: unwrap Result<Response, Response> into a Response.
      case consume_request(ctx, data) {
        Ok(resp) -> resp
        Error(resp) -> resp
      }
    }
  }
}

fn create_reset(
  ctx: Ctx,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use email_raw <- result.try(decode_reset_request(data))
  use email <- result.try(require_email(email_raw))

  let token = password_resets_db.new_reset_token()
  let url_path = "/reset-password?token=" <> token

  let Ctx(db: db) = ctx
  use _ <- result.try(store_reset_token(db, email, token))

  Ok(ok_reset_payload(token, url_path))
}

fn consume_request(
  ctx: Ctx,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use #(token, password_raw) <- result.try(decode_consume_payload(data))
  use _ <- result.try(validate_password(password_raw))
  use _ <- result.try(consume_password_reset(ctx, token, password_raw))

  Ok(api.no_content())
}

fn decode_reset_request(data: dynamic.Dynamic) -> Result(String, wisp.Response) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    decode.success(email)
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn require_email(email_raw: String) -> Result(String, wisp.Response) {
  let email = string.trim(email_raw)

  case email == "" {
    True -> Error(api.error(422, "VALIDATION_ERROR", "Email is required"))
    False -> Ok(email)
  }
}

fn store_reset_token(
  db: pog.Connection,
  email: String,
  token: String,
) -> Result(Nil, wisp.Response) {
  case password_resets_db.user_exists(db, email) {
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
    Ok(False) -> Ok(Nil)
    Ok(True) -> persist_reset_token(db, email, token)
  }
}

fn persist_reset_token(
  db: pog.Connection,
  email: String,
  token: String,
) -> Result(Nil, wisp.Response) {
  let tx_result =
    pog.transaction(db, fn(tx) {
      use _ <- result.try(password_resets_db.invalidate_active_for_email(
        tx,
        email,
      ))
      use _ <- result.try(password_resets_db.insert_reset(tx, email, token))
      Ok(Nil)
    })

  case tx_result {
    Ok(_) -> Ok(Nil)
    Error(pog.TransactionQueryError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(pog.TransactionRolledBack(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn decode_consume_payload(
  data: dynamic.Dynamic,
) -> Result(#(String, String), wisp.Response) {
  let decoder = {
    use token <- decode.field("token", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(#(token, password))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn validate_password(password_raw: String) -> Result(Nil, wisp.Response) {
  case string.length(password_raw) < 12 {
    True ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Password must be at least 12 characters",
      ))
    False -> Ok(Nil)
  }
}

fn consume_password_reset(
  ctx: Ctx,
  token: String,
  password_raw: String,
) -> Result(Nil, wisp.Response) {
  let Ctx(db: db) = ctx

  let tx_result =
    pog.transaction(db, fn(tx) { consume_token_in_tx(tx, token, password_raw) })

  case tx_result {
    Ok(_) -> Ok(Nil)
    Error(pog.TransactionQueryError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(pog.TransactionRolledBack(err)) -> Error(map_consume_error(err))
  }
}

fn consume_token_in_tx(
  tx: pog.Connection,
  token: String,
  password_raw: String,
) -> Result(Nil, ConsumeTxError) {
  use status <- result.try(
    password_resets_db.token_status_for_update(tx, token)
    |> result.map_error(ConsumeDbError),
  )

  case status {
    password_resets_db.TokenActive(email: email) ->
      consume_active_token(tx, token, password_raw, email)

    password_resets_db.TokenUsed -> Error(ConsumeUsedToken)

    _ -> Error(ConsumeInvalidToken)
  }
}

fn consume_active_token(
  tx: pog.Connection,
  token: String,
  password_raw: String,
  email: String,
) -> Result(Nil, ConsumeTxError) {
  use password_hash <- result.try(
    password.hash(password_raw)
    |> result.map_error(fn(_) { ConsumePasswordHashError }),
  )

  use updated <- result.try(
    password_resets_db.update_user_password_hash(tx, email, password_hash)
    |> result.map_error(ConsumeDbError),
  )

  case updated {
    False -> Error(ConsumeInvalidToken)
    True -> mark_token_used(tx, token)
  }
}

fn mark_token_used(
  tx: pog.Connection,
  token: String,
) -> Result(Nil, ConsumeTxError) {
  use used <- result.try(
    password_resets_db.mark_used(tx, token)
    |> result.map_error(ConsumeDbError),
  )

  case used {
    True -> Ok(Nil)
    False -> Error(ConsumeInvalidToken)
  }
}

fn map_consume_error(err: ConsumeTxError) -> wisp.Response {
  case err {
    ConsumeUsedToken ->
      api.error(403, "RESET_TOKEN_USED", "Reset token already used")

    ConsumePasswordHashError ->
      api.error(500, "INTERNAL", "Password hashing failed")

    ConsumeDbError(_) -> api.error(500, "INTERNAL", "Database error")

    ConsumeInvalidToken ->
      api.error(403, "RESET_TOKEN_INVALID", "Reset token invalid")
  }
}
