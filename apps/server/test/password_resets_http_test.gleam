import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/json
import gleam/list
import gleam/string
import gleeunit/should
import pog
import scrumbringer_server
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

pub fn request_reset_does_not_leak_unknown_email_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let known_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  known_res.status |> should.equal(200)
  let known_token = decode_reset_token(simulate.read_body(known_res))

  let unknown_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("nope@example.com"))]),
      ),
    )

  unknown_res.status |> should.equal(200)
  let unknown_token = decode_reset_token(simulate.read_body(unknown_res))

  let known_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> known_token,
    ))

  known_validate.status |> should.equal(200)
  string.contains(simulate.read_body(known_validate), "admin@example.com")
  |> should.be_true

  let unknown_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> unknown_token,
    ))

  unknown_validate.status |> should.equal(403)
  string.contains(simulate.read_body(unknown_validate), "RESET_TOKEN_INVALID")
  |> should.be_true

  // Unknown token should not be persisted
  single_int(db, "select count(*) from password_resets where token = $1", [
    pog.text(unknown_token),
  ])
  |> should.equal(0)
}

pub fn request_reset_invalidates_previous_active_token_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let first_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  first_res.status |> should.equal(200)
  let first_token = decode_reset_token(simulate.read_body(first_res))

  let second_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  second_res.status |> should.equal(200)
  let second_token = decode_reset_token(simulate.read_body(second_res))

  let first_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> first_token,
    ))

  first_validate.status |> should.equal(403)
  string.contains(simulate.read_body(first_validate), "RESET_TOKEN_INVALID")
  |> should.be_true

  let second_validate =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/password-resets/" <> second_token,
    ))

  second_validate.status |> should.equal(200)
}

pub fn reset_token_is_single_use_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let create_res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/password-resets")
      |> simulate.json_body(
        json.object([#("email", json.string("admin@example.com"))]),
      ),
    )

  create_res.status |> should.equal(200)
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

  consume_res.status |> should.equal(204)

  let validate_again =
    handler(simulate.request(http.Get, "/api/v1/auth/password-resets/" <> token))

  validate_again.status |> should.equal(403)
  string.contains(simulate.read_body(validate_again), "RESET_TOKEN_USED")
  |> should.be_true

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

  consume_again.status |> should.equal(403)
  string.contains(simulate.read_body(consume_again), "RESET_TOKEN_USED")
  |> should.be_true
}

pub fn validate_rejects_expired_tokens_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  insert_reset_expired(db, "pr_old", "admin@example.com")

  let validate =
    handler(simulate.request(http.Get, "/api/v1/auth/password-resets/pr_old"))

  validate.status |> should.equal(403)
  string.contains(simulate.read_body(validate), "RESET_TOKEN_INVALID")
  |> should.be_true
}

fn decode_reset_token(body: String) -> String {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let token_decoder = decode.field("token", decode.string, decode.success)
  let reset_decoder = decode.field("reset", token_decoder, decode.success)
  let decoder = decode.field("data", reset_decoder, decode.success)

  let assert Ok(token) = decode.run(dynamic, decoder)
  token
}

fn new_test_app() -> scrumbringer_server.App {
  let database_url = require_database_url()

  let assert Ok(app) = scrumbringer_server.new_app(secret, database_url)
  app
}

fn bootstrap_app() -> scrumbringer_server.App {
  let app = new_test_app()
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  reset_db(db)

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/register")
      |> simulate.json_body(
        json.object([
          #("email", json.string("admin@example.com")),
          #("password", json.string("passwordpassword")),
          #("org_name", json.string("Acme")),
        ]),
      ),
    )
  res.status |> should.equal(200)

  app
}

fn require_database_url() -> String {
  case getenv("DATABASE_URL", "") {
    "" -> {
      should.fail()
      ""
    }

    url -> url
  }
}

fn reset_db(db: pog.Connection) {
  let assert Ok(_) =
    pog.query(
      "TRUNCATE password_resets, project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn single_int(db: pog.Connection, sql: String, params: List(pog.Value)) -> Int {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  let query = pog.query(sql)
  let query =
    params
    |> list.fold(query, fn(q, p) { pog.parameter(q, p) })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query |> pog.returning(decoder) |> pog.execute(db)

  value
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

fn getenv(key: String, default: String) -> String {
  getenv_charlist(charlist.from_string(key), charlist.from_string(default))
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
