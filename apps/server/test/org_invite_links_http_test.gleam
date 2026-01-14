import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import pog
import scrumbringer_server
import wisp
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

pub fn non_admin_forbidden_for_invite_links_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  create_member_user(handler, db)

  let login_res = login_as(handler, "member@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let create_req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string("a@b.com"))]))

  let create_res = handler(create_req)
  create_res.status |> should.equal(403)

  let list_req =
    simulate.request(http.Get, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)

  let list_res = handler(list_req)
  list_res.status |> should.equal(403)
}

pub fn missing_csrf_is_rejected_for_create_and_regenerate_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let create_req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> simulate.json_body(json.object([#("email", json.string("a@b.com"))]))

  let create_res = handler(create_req)
  create_res.status |> should.equal(403)

  let regen_req =
    simulate.request(http.Post, "/api/v1/org/invite-links/regenerate")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> simulate.json_body(json.object([#("email", json.string("a@b.com"))]))

  let regen_res = handler(regen_req)
  regen_res.status |> should.equal(403)
}

pub fn create_invalidates_previous_active_token_for_email_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let email = "User@Example.com"

  let req1 =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  let res1 = handler(req1)
  res1.status |> should.equal(200)

  let token1 =
    single_text(
      db,
      "select token from org_invite_links where email = $1 order by created_at desc limit 1",
      [pog.text("user@example.com")],
    )

  let req2 =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  let res2 = handler(req2)
  res2.status |> should.equal(200)

  let token2 =
    single_text(
      db,
      "select token from org_invite_links where email = $1 and invalidated_at is null and used_at is null order by created_at desc limit 1",
      [pog.text("user@example.com")],
    )

  let same = token1 == token2
  same |> should.be_false

  let invalidated =
    single_int(
      db,
      "select (invalidated_at is not null)::int from org_invite_links where token = $1",
      [pog.text(token1)],
    )

  invalidated |> should.equal(1)
}

pub fn list_sorted_by_email_asc_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let create = fn(email) {
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string(email))]))
    |> handler
  }

  create("b@example.com").status |> should.equal(200)
  create("a@example.com").status |> should.equal(200)

  let list_req =
    simulate.request(http.Get, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)

  let res = handler(list_req)
  res.status |> should.equal(200)

  let body = simulate.read_body(res)

  let decoder = {
    use invite_links <- decode.field(
      "invite_links",
      decode.list(invite_email_decoder()),
    )
    decode.success(invite_links)
  }

  let parsed =
    json.parse(from: body, using: decode.field("data", decoder, decode.success))

  let assert Ok(emails) = parsed

  emails |> should.equal(["a@example.com", "b@example.com"])
}

pub fn no_time_expiry_links_stay_active_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let email = "old@example.com"

  let req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  let res = handler(req)
  res.status |> should.equal(200)

  let token =
    single_text(
      db,
      "select token from org_invite_links where email = $1 and invalidated_at is null and used_at is null order by created_at desc limit 1",
      [pog.text(email)],
    )

  // Simulate a very old invite; it should still be active because we do not enforce expires_at.
  let assert Ok(_) =
    pog.query(
      "update org_invite_links set created_at = timestamptz '2000-01-01T00:00:00Z' where token = $1",
    )
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)

  let list_req =
    simulate.request(http.Get, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)

  let list_res = handler(list_req)
  list_res.status |> should.equal(200)

  string.contains(simulate.read_body(list_res), "\"state\":\"active\"")
  |> should.be_true
}

pub fn regenerate_creates_new_token_and_invalidates_previous_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let email = "regen@example.com"

  let create_req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  handler(create_req).status |> should.equal(200)

  let token1 =
    single_text(
      db,
      "select token from org_invite_links where email = $1 and invalidated_at is null and used_at is null order by created_at desc limit 1",
      [pog.text(email)],
    )

  let regen_req =
    simulate.request(http.Post, "/api/v1/org/invite-links/regenerate")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  handler(regen_req).status |> should.equal(200)

  let token2 =
    single_text(
      db,
      "select token from org_invite_links where email = $1 and invalidated_at is null and used_at is null order by created_at desc limit 1",
      [pog.text(email)],
    )

  let same = token1 == token2
  same |> should.be_false

  single_int(
    db,
    "select (invalidated_at is not null)::int from org_invite_links where token = $1",
    [pog.text(token1)],
  )
  |> should.equal(1)
}

pub fn invalid_email_returns_422_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([#("email", json.string("not-an-email"))]),
    )

  let res = handler(req)
  res.status |> should.equal(422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> should.be_true
}

pub fn list_includes_invalidated_links_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  login_res.status |> should.equal(200)

  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let email = "inv@example.com"

  let create = fn() {
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("email", json.string(email))]))
    |> handler
  }

  create().status |> should.equal(200)
  create().status |> should.equal(200)

  let list_req =
    simulate.request(http.Get, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session)

  let res = handler(list_req)
  res.status |> should.equal(200)

  let body = simulate.read_body(res)

  let decoder = {
    use pairs <- decode.field(
      "invite_links",
      decode.list(invite_email_state_decoder()),
    )
    decode.success(pairs)
  }

  let parsed =
    json.parse(from: body, using: decode.field("data", decoder, decode.success))
  let assert Ok(pairs) = parsed

  let invalidated_count =
    pairs
    |> list.filter(fn(p) { p.1 == "invalidated" })
    |> list.length

  let has_invalidated = invalidated_count > 0
  has_invalidated |> should.be_true
}

fn invite_email_decoder() -> decode.Decoder(String) {
  decode.field("email", decode.string, decode.success)
}

fn invite_email_state_decoder() -> decode.Decoder(#(String, String)) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    use state <- decode.field("state", decode.string)
    decode.success(#(email, state))
  }

  decoder
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
    handler(bootstrap_request("admin@example.com", "passwordpassword", "Acme"))
  res.status |> should.equal(200)

  app
}

fn bootstrap_request(email: String, password: String, org_name: String) {
  simulate.request(http.Post, "/api/v1/auth/register")
  |> simulate.json_body(
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
      #("org_name", json.string(org_name)),
    ]),
  )
}

fn create_member_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
) {
  insert_invite_link_active(db, "il_member", "member@example.com")

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_member")),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(200)
}

fn login_as(
  handler: fn(wisp.Request) -> wisp.Response,
  email: String,
  password: String,
) -> wisp.Response {
  let req =
    simulate.request(http.Post, "/api/v1/auth/login")
    |> simulate.json_body(
      json.object([
        #("email", json.string(email)),
        #("password", json.string(password)),
      ]),
    )

  handler(req)
}

fn set_cookie_headers(headers: List(#(String, String))) -> List(String) {
  headers
  |> list.filter_map(fn(h) {
    case h.0 {
      "set-cookie" -> Ok(h.1)
      _ -> Error(Nil)
    }
  })
}

fn find_cookie_value(headers: List(#(String, String)), name: String) -> String {
  let target = name <> "="

  let assert Ok(header) =
    set_cookie_headers(headers)
    |> list.find(fn(h) { string.starts_with(h, target) })

  let #(value, _) =
    header
    |> string.drop_start(string.length(target))
    |> string.split_once(";")
    |> result.unwrap(#("", ""))

  value
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
      "TRUNCATE project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn insert_invite_valid(db: pog.Connection, code: String) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invites (code, org_id, created_by, expires_at) values ($1, 1, 1, timestamptz '2999-01-01T00:00:00Z')",
    )
    |> pog.parameter(pog.text(code))
    |> pog.execute(db)

  Nil
}

fn insert_invite_link_active(db: pog.Connection, token: String, email: String) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invite_links (org_id, email, token, created_by) values (1, $1, $2, 1)",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)

  Nil
}

fn single_text(
  db: pog.Connection,
  sql: String,
  params: List(pog.Value),
) -> String {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn single_int(db: pog.Connection, sql: String, params: List(pog.Value)) -> Int {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
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
