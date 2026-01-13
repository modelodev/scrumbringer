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
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

pub fn bootstrap_happy_path_creates_org_default_project_and_membership_test() {
  let app = new_test_app()
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  reset_db(db)

  let res = handler(bootstrap_request("admin@example.com", "password", "Acme"))
  res.status |> should.equal(200)

  let org_name = single_text(db, "select name from organizations where id = 1")
  org_name |> should.equal("Acme")

  let default_projects =
    single_int(
      db,
      "select count(*) from projects where org_id = 1 and name = 'Default'",
    )
  default_projects |> should.equal(1)

  let admin_user_count =
    single_int(
      db,
      "select count(*) from users where org_id = 1 and org_role = 'admin'",
    )
  admin_user_count |> should.equal(1)

  let admin_memberships =
    single_int(
      db,
      "select count(*) from project_members where user_id = 1 and role = 'admin'",
    )
  admin_memberships |> should.equal(1)
}

pub fn register_sets_session_and_csrf_cookies_test() {
  let app = new_test_app()
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  reset_db(db)

  let res = handler(bootstrap_request("admin@example.com", "password", "Acme"))
  res.status |> should.equal(200)

  let cookies = set_cookie_headers(res.headers)
  list.length(cookies) |> should.equal(2)

  let has_session_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_session=")
      && string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Strict")
      && string.contains(h, "Path=/")
    })

  has_session_cookie |> should.be_true

  let has_csrf_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_csrf=")
      && !string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Strict")
      && string.contains(h, "Path=/")
    })

  has_csrf_cookie |> should.be_true
}

pub fn register_after_bootstrap_requires_invite_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("email", json.string("member@example.com")),
        #("password", json.string("password")),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "INVITE_REQUIRED")
  |> should.be_true
}

pub fn register_consumes_invite_once_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  insert_invite_valid(db, "inv_once")

  let first_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("email", json.string("first@example.com")),
        #("password", json.string("password")),
        #("invite_code", json.string("inv_once")),
      ]),
    )

  let first_res = handler(first_req)
  first_res.status |> should.equal(200)

  let second_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("email", json.string("second@example.com")),
        #("password", json.string("password")),
        #("invite_code", json.string("inv_once")),
      ]),
    )

  let second_res = handler(second_req)
  second_res.status |> should.equal(403)
  string.contains(simulate.read_body(second_res), "INVITE_USED")
  |> should.be_true
}

pub fn register_rejects_invalid_expired_and_used_invites_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  insert_invite_expired(db, "inv_expired")
  insert_invite_used(db, "inv_used")

  let invalid_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("email", json.string("invalid@example.com")),
        #("password", json.string("password")),
        #("invite_code", json.string("inv_missing")),
      ]),
    )

  let invalid_res = handler(invalid_req)
  invalid_res.status |> should.equal(403)
  string.contains(simulate.read_body(invalid_res), "INVITE_INVALID")
  |> should.be_true

  let expired_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("email", json.string("expired@example.com")),
        #("password", json.string("password")),
        #("invite_code", json.string("inv_expired")),
      ]),
    )

  let expired_res = handler(expired_req)
  expired_res.status |> should.equal(403)
  string.contains(simulate.read_body(expired_res), "INVITE_EXPIRED")
  |> should.be_true

  let used_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("email", json.string("used@example.com")),
        #("password", json.string("password")),
        #("invite_code", json.string("inv_used")),
      ]),
    )

  let used_res = handler(used_req)
  used_res.status |> should.equal(403)
  string.contains(simulate.read_body(used_res), "INVITE_USED")
  |> should.be_true
}

pub fn login_sets_session_and_csrf_cookies_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let res = login(handler)
  res.status |> should.equal(200)

  let cookies = set_cookie_headers(res.headers)
  list.length(cookies) |> should.equal(2)

  let has_session_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_session=")
      && string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Strict")
      && string.contains(h, "Path=/")
    })

  has_session_cookie |> should.be_true

  let has_csrf_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_csrf=")
      && !string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Strict")
      && string.contains(h, "Path=/")
    })

  has_csrf_cookie |> should.be_true
}

pub fn me_requires_auth_and_returns_user_when_authenticated_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let unauth_res = handler(simulate.request(http.Get, "/api/v1/auth/me"))
  unauth_res.status |> should.equal(401)
  string.contains(simulate.read_body(unauth_res), "AUTH_REQUIRED")
  |> should.be_true

  let login_res = login(handler)
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let authed_req =
    simulate.request(http.Get, "/api/v1/auth/me")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)

  let authed_res = handler(authed_req)
  authed_res.status |> should.equal(200)
  string.contains(simulate.read_body(authed_res), "admin@example.com")
  |> should.be_true
}

pub fn logout_clears_cookies_and_csrf_is_required_for_logout_mutation_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let login_res = login(handler)
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let bad_req =
    simulate.request(http.Post, "/api/v1/auth/logout")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)

  let bad_res = handler(bad_req)
  bad_res.status |> should.equal(403)
  list.length(set_cookie_headers(bad_res.headers)) |> should.equal(0)

  let ok_req =
    simulate.request(http.Post, "/api/v1/auth/logout")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)

  let ok_res = handler(ok_req)
  ok_res.status |> should.equal(204)

  let cookies = set_cookie_headers(ok_res.headers)
  list.length(cookies) |> should.equal(2)

  let clears_session =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_session=")
      && string.contains(h, "Max-Age=0")
      && string.contains(h, "Expires=Thu, 01 Jan 1970")
    })

  clears_session |> should.be_true

  let clears_csrf =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_csrf=")
      && string.contains(h, "Max-Age=0")
      && string.contains(h, "Expires=Thu, 01 Jan 1970")
    })

  clears_csrf |> should.be_true
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

  let res = handler(bootstrap_request("admin@example.com", "password", "Acme"))
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

fn login(handler) {
  let req =
    simulate.request(http.Post, "/api/v1/auth/login")
    |> simulate.json_body(
      json.object([
        #("email", json.string("admin@example.com")),
        #("password", json.string("password")),
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
      "TRUNCATE project_members, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn insert_invite_expired(db: pog.Connection, code: String) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invites (code, org_id, created_by, expires_at) values ($1, 1, 1, timestamptz '2000-01-01T00:00:00Z')",
    )
    |> pog.parameter(pog.text(code))
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

fn insert_invite_used(db: pog.Connection, code: String) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invites (code, org_id, created_by, expires_at, used_at, used_by) values ($1, 1, 1, timestamptz '2999-01-01T00:00:00Z', timestamptz '2000-01-01T00:00:00Z', 1)",
    )
    |> pog.parameter(pog.text(code))
    |> pog.execute(db)

  Nil
}

fn single_text(db: pog.Connection, sql: String) -> String {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    pog.query(sql)
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn single_int(db: pog.Connection, sql: String) -> Int {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    pog.query(sql)
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
