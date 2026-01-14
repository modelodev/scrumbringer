import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/result
import gleam/string
import pog

import scrumbringer_server/http/api
import scrumbringer_server/services/password
import scrumbringer_server/services/password_resets_db
import wisp

pub type Ctx {
  Ctx(db: pog.Connection)
}

type ConsumeTxError {
  ConsumeInvalidToken
  ConsumeUsedToken
  ConsumePasswordHashError
  ConsumeDbError(pog.QueryError)
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
                    password_resets_db.invalidate_active_for_email(tx, email),
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

fn handle_consume_post(req: wisp.Request, ctx: Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
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
                  api.error(403, "RESET_TOKEN_USED", "Reset token already used")

                ConsumePasswordHashError ->
                  api.error(500, "INTERNAL", "Password hashing failed")

                ConsumeDbError(_) ->
                  api.error(500, "INTERNAL", "Database error")

                _ ->
                  api.error(403, "RESET_TOKEN_INVALID", "Reset token invalid")
              }
            }
          }
        }
      }
    }
  }
}
