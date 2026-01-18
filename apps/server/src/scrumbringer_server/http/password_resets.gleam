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
//// ## Line Count Justification
////
//// `handle_consume_post` (~112 lines) handles transactional password update
//// with comprehensive error recovery. Splitting would fragment the atomic
//// transaction logic and error mapping.

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

pub fn handle_password_resets(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  case req.method {
    http.Post -> handle_create(req, ctx)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

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

pub fn handle_consume(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  case req.method {
    http.Post -> handle_consume_post(req, ctx)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

fn handle_create(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case rate_limit_ok("password_resets_request", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use email <- decode.field("email", decode.string)
        decode.success(email)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(email_raw) -> {
          let email = string.trim(email_raw)

          case email == "" {
            True -> api.error(422, "VALIDATION_ERROR", "Email is required")

            False -> {
              let token = password_resets_db.new_reset_token()
              let url_path = "/reset-password?token=" <> token

              let Ctx(db: db) = ctx

              case password_resets_db.user_exists(db, email) {
                Error(_) -> api.error(500, "INTERNAL", "Database error")

                Ok(True) -> {
                  let tx_result =
                    pog.transaction(db, fn(tx) {
                      use _ <- result.try(
                        password_resets_db.invalidate_active_for_email(
                          tx,
                          email,
                        ),
                      )
                      use _ <- result.try(password_resets_db.insert_reset(
                        tx,
                        email,
                        token,
                      ))
                      Ok(Nil)
                    })

                  case tx_result {
                    Ok(_) -> ok_reset_payload(token, url_path)

                    Error(pog.TransactionQueryError(_)) ->
                      api.error(500, "INTERNAL", "Database error")

                    Error(pog.TransactionRolledBack(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                  }
                }

                Ok(False) -> ok_reset_payload(token, url_path)
              }
            }
          }
        }
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

fn handle_consume_post(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case rate_limit_ok("password_resets_consume", req) {
    False -> api.error(429, "RATE_LIMITED", "Too many attempts")

    True -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use token <- decode.field("token", decode.string)
        use password <- decode.field("password", decode.string)
        decode.success(#(token, password))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(token, password_raw)) -> {
          case string.length(password_raw) < 12 {
            True ->
              api.error(
                422,
                "VALIDATION_ERROR",
                "Password must be at least 12 characters",
              )

            False -> {
              let Ctx(db: db) = ctx

              let result =
                pog.transaction(db, fn(tx) {
                  use status <- result.try(
                    password_resets_db.token_status_for_update(tx, token)
                    |> result.map_error(ConsumeDbError),
                  )

                  case status {
                    password_resets_db.TokenActive(email: email) -> {
                      use password_hash <- result.try(
                        password.hash(password_raw)
                        |> result.map_error(fn(_) { ConsumePasswordHashError }),
                      )

                      use updated <- result.try(
                        password_resets_db.update_user_password_hash(
                          tx,
                          email,
                          password_hash,
                        )
                        |> result.map_error(ConsumeDbError),
                      )

                      case updated {
                        False -> Error(ConsumeInvalidToken)

                        True -> {
                          use used <- result.try(
                            password_resets_db.mark_used(tx, token)
                            |> result.map_error(ConsumeDbError),
                          )

                          case used {
                            True -> Ok(Nil)
                            False -> Error(ConsumeInvalidToken)
                          }
                        }
                      }
                    }

                    password_resets_db.TokenUsed -> Error(ConsumeUsedToken)

                    _ -> Error(ConsumeInvalidToken)
                  }
                })

              case result {
                Ok(_) -> api.no_content()

                Error(pog.TransactionQueryError(_)) ->
                  api.error(500, "INTERNAL", "Database error")

                Error(pog.TransactionRolledBack(err)) -> {
                  case err {
                    ConsumeUsedToken ->
                      api.error(
                        403,
                        "RESET_TOKEN_USED",
                        "Reset token already used",
                      )

                    ConsumePasswordHashError ->
                      api.error(500, "INTERNAL", "Password hashing failed")

                    ConsumeDbError(_) ->
                      api.error(500, "INTERNAL", "Database error")

                    _ ->
                      api.error(
                        403,
                        "RESET_TOKEN_INVALID",
                        "Reset token invalid",
                      )
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
