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
//// - Token generation (see `use_case/password_resets_db.gleam`)
//// - Password hashing (see `use_case/password.gleam`)
////

import gleam/http
import gleam/option as opt
import gleam/result
import pog

import scrumbringer_server/http/api
import scrumbringer_server/http/client_ip
import scrumbringer_server/http/password_resets/payloads as reset_payloads
import scrumbringer_server/http/password_resets/presenters as reset_presenters
import scrumbringer_server/use_case/password
import scrumbringer_server/use_case/password_resets_db
import scrumbringer_server/use_case/rate_limit
import scrumbringer_server/use_case/time
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

fn rate_limit_key(prefix: String, req: wisp.Request) -> opt.Option(String) {
  client_ip.from_request(req)
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

fn require_rate_limit(
  prefix: String,
  req: wisp.Request,
) -> Result(Nil, wisp.Response) {
  case rate_limit_ok(prefix, req) {
    True -> Ok(Nil)
    False -> Error(api.error(429, "RATE_LIMITED", "Too many attempts"))
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

fn handle_create(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  with_rate_limited_payload(
    req,
    "password_resets_request",
    decode_reset_request,
    fn(payload) { create_reset(ctx, payload) },
  )
}

fn ok_reset_payload(token: String, url_path: String) -> wisp.Response {
  api.ok(reset_presenters.reset(token, url_path))
}

fn handle_validate(req: wisp.Request, ctx: Ctx, token: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case require_rate_limit("password_resets_validate", req) {
    Error(resp) -> resp
    Ok(Nil) -> validate_token(ctx, token)
  }
}

fn handle_consume_post(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  with_rate_limited_payload(
    req,
    "password_resets_consume",
    decode_consume_payload,
    fn(payload) { consume_request(ctx, payload) },
  )
}

fn with_rate_limited_payload(
  req: wisp.Request,
  prefix: String,
  decode_payload,
  handle_payload: fn(payload) -> Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case require_rate_limit(prefix, req) {
    Error(resp) -> resp
    Ok(Nil) -> {
      use data <- wisp.require_json(req)
      case decode_payload(data) {
        Error(resp) -> resp
        Ok(payload) -> response_from_result(handle_payload(payload))
      }
    }
  }
}

fn response_from_result(
  result: Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case result {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn validate_token(ctx: Ctx, token: String) -> wisp.Response {
  let Ctx(db: db) = ctx

  case password_resets_db.token_status(db, token) {
    Error(_) -> api.error(500, "INTERNAL", "Database error")
    Ok(status) -> token_status_to_response(status)
  }
}

fn token_status_to_response(
  status: password_resets_db.TokenStatus,
) -> wisp.Response {
  case status {
    password_resets_db.TokenActive(email: email) ->
      api.ok(reset_presenters.token_email(email))

    password_resets_db.TokenUsed ->
      api.error(403, "RESET_TOKEN_USED", "Reset token already used")

    password_resets_db.TokenMissing
    | password_resets_db.TokenInvalidated
    | password_resets_db.TokenExpired ->
      api.error(403, "RESET_TOKEN_INVALID", "Reset token invalid")
  }
}

fn create_reset(
  ctx: Ctx,
  payload: reset_payloads.ResetRequestPayload,
) -> Result(wisp.Response, wisp.Response) {
  let token = password_resets_db.new_reset_token()
  let url_path = "/reset-password?token=" <> token

  let Ctx(db: db) = ctx
  use _ <- result.try(store_reset_token(db, payload.email, token))

  Ok(ok_reset_payload(token, url_path))
}

fn consume_request(
  ctx: Ctx,
  payload: reset_payloads.ConsumePayload,
) -> Result(wisp.Response, wisp.Response) {
  use _ <- result.try(consume_password_reset(
    ctx,
    payload.token,
    payload.password,
  ))

  Ok(api.no_content())
}

fn decode_reset_request(
  data,
) -> Result(reset_payloads.ResetRequestPayload, wisp.Response) {
  reset_payloads.decode_reset_request(data)
  |> result.map_error(payload_error_to_response)
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
  data,
) -> Result(reset_payloads.ConsumePayload, wisp.Response) {
  reset_payloads.decode_consume(data)
  |> result.map_error(payload_error_to_response)
}

fn payload_error_to_response(error: reset_payloads.DecodeError) -> wisp.Response {
  case error {
    reset_payloads.InvalidJson ->
      api.error(400, "VALIDATION_ERROR", "Invalid JSON")
    reset_payloads.EmailRequired ->
      api.error(422, "VALIDATION_ERROR", "Email is required")
    reset_payloads.PasswordTooShort ->
      api.error(
        422,
        "VALIDATION_ERROR",
        "Password must be at least 12 characters",
      )
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
