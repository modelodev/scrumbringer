import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn request_reset_does_not_leak_unknown_email_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let known_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  expect.expect_status(known_res, 200)
  let known_token = decode_reset_token(simulate.read_body(known_res))

  let unknown_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("nope@example.com"))]),
      ),
    )

  expect.expect_status(unknown_res, 200)
  let unknown_token = decode_reset_token(simulate.read_body(unknown_res))

  let known_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> known_token,
    ))

  expect.expect_status(known_validate, 200)
  string.contains(simulate.read_body(known_validate), "admin@example.com")
  |> expect.is_true

  let unknown_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> unknown_token,
    ))

  expect.expect_status(unknown_validate, 403)
  string.contains(simulate.read_body(unknown_validate), "RESET_TOKEN_INVALID")
  |> expect.is_true

  // Unknown token should not be persisted
  fixtures.require_query_int(
    db,
    "select count(*) from password_resets where token = $1",
    [pog.text(unknown_token)],
  )
  |> expect.equal(0)
}

pub fn request_reset_invalidates_previous_active_token_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let first_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  expect.expect_status(first_res, 200)
  let first_token = decode_reset_token(simulate.read_body(first_res))

  let second_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  expect.expect_status(second_res, 200)
  let second_token = decode_reset_token(simulate.read_body(second_res))

  let first_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> first_token,
    ))

  expect.expect_status(first_validate, 403)
  string.contains(simulate.read_body(first_validate), "RESET_TOKEN_INVALID")
  |> expect.is_true

  let second_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> second_token,
    ))

  expect.expect_status(second_validate, 200)
}

pub fn reset_token_is_single_use_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let create_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  expect.expect_status(create_res, 200)
  let token = decode_reset_token(simulate.read_body(create_res))

  let consume_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets/consume")
      |> simulate.json_body(
        json.object([
          #("token", json.string(token)),
          #("password", json.string("passwordpassword")),
        ]),
      ),
    )

  expect.expect_status(consume_res, 204)

  let validate_again =
    handler(simulate.request(http.Get, "/api/v1/auth/password-resets/" <> token))

  expect.expect_status(validate_again, 403)
  string.contains(simulate.read_body(validate_again), "RESET_TOKEN_USED")
  |> expect.is_true

  let consume_again =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets/consume")
      |> simulate.json_body(
        json.object([
          #("token", json.string(token)),
          #("password", json.string("passwordpassword")),
        ]),
      ),
    )

  expect.expect_status(consume_again, 403)
  string.contains(simulate.read_body(consume_again), "RESET_TOKEN_USED")
  |> expect.is_true
}

pub fn consume_rejects_short_password_and_keeps_token_active_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let create_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  expect.expect_status(create_res, 200)
  let token = decode_reset_token(simulate.read_body(create_res))

  let consume_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets/consume")
      |> simulate.json_body(
        json.object([
          #("token", json.string(token)),
          #("password", json.string("12345678901")),
        ]),
      ),
    )

  expect.expect_status(consume_res, 422)
  string.contains(simulate.read_body(consume_res), "VALIDATION_ERROR")
  |> expect.is_true
  string.contains(simulate.read_body(consume_res), "at least 12")
  |> expect.is_true

  let validate =
    handler(simulate.request(http.Get, "/api/v1/auth/password-resets/" <> token))

  expect.expect_status(validate, 200)
  string.contains(simulate.read_body(validate), "admin@example.com")
  |> expect.is_true
}

pub fn validate_rejects_expired_tokens_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  insert_reset_expired(db, "pr_old", "admin@example.com")

  let validate =
    handler(simulate.request(http.Get, "/api/v1/auth/password-resets/pr_old"))

  expect.expect_status(validate, 403)
  string.contains(simulate.read_body(validate), "RESET_TOKEN_INVALID")
  |> expect.is_true
}

fn decode_reset_token(body: String) -> String {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let token_decoder = decode.field("token", decode.string, decode.success)
  let reset_decoder = decode.field("reset", token_decoder, decode.success)
  let decoder = decode.field("data", reset_decoder, decode.success)

  let assert Ok(token) = decode.run(dynamic, decoder)
  token
}

fn insert_reset_expired(db: pog.Connection, token: String, email: String) {
  let assert Ok(_) =
    pog.query(
      "insert into password_resets (token, email, created_at) values ($1, $2, now() - interval '25 hours')",
    )
    |> pog.parameter(pog.text(token))
    |> pog.parameter(pog.text(email))
    |> pog.execute(db)

  Nil
}
