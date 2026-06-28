import fixtures
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn bootstrap_happy_path_creates_org_default_project_and_membership_test() {
  let app = fixtures.new_app() |> expect.ok
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  fixtures.reset_database(db) |> expect.ok

  let res =
    handler(bootstrap_request("admin@example.com", "passwordpassword", "Acme"))
  expect.expect_status(res, 200)

  let org_name =
    fixtures.query_string(db, "select name from organizations where id = 1", [])
    |> expect.ok
  org_name |> expect.equal("Acme")

  let default_projects =
    fixtures.query_int(
      db,
      "select count(*) from projects where org_id = 1 and name = 'Default'",
      [],
    )
    |> expect.ok
  default_projects |> expect.equal(1)

  let admin_user_count =
    fixtures.query_int(
      db,
      "select count(*) from users where org_id = 1 and org_role = 'admin'",
      [],
    )
    |> expect.ok
  admin_user_count |> expect.equal(1)

  let admin_memberships =
    fixtures.query_int(
      db,
      "select count(*) from project_members where user_id = 1 and role = 'manager'",
      [],
    )
    |> expect.ok
  admin_memberships |> expect.equal(1)
}

pub fn register_sets_session_and_csrf_cookies_test() {
  let app = fixtures.new_app() |> expect.ok
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  fixtures.reset_database(db) |> expect.ok

  let res =
    handler(bootstrap_request("admin@example.com", "passwordpassword", "Acme"))
  expect.expect_status(res, 200)

  let cookies = set_cookie_headers(res.headers)
  list.length(cookies) |> expect.equal(2)

  let has_session_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_session=")
      && string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Lax")
      && string.contains(h, "Path=/")
    })

  has_session_cookie |> expect.is_true

  let has_csrf_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_csrf=")
      && !string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Lax")
      && string.contains(h, "Path=/")
    })

  has_csrf_cookie |> expect.is_true
}

pub fn register_after_bootstrap_requires_invite_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([#("password", json.string("passwordpassword"))]),
    )

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "INVITE_REQUIRED")
  |> expect.is_true
}

pub fn register_rejects_short_password_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  insert_invite_link_active(db, "il_short", "short@example.com")

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("short")),
        #("invite_token", json.string("il_short")),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR")
  |> expect.is_true
}

pub fn validate_invite_link_returns_email_when_active_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  insert_invite_link_active(db, "il_active", "member@example.com")

  let res =
    handler(simulate.request(http.Get, "/api/v1/auth/invite-links/il_active"))

  expect.expect_status(res, 200)
  string.contains(simulate.read_body(res), "member@example.com")
  |> expect.is_true
}

pub fn validate_invite_link_rejects_missing_invalidated_and_used_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  insert_invite_link_invalidated(db, "il_invalidated", "inv@example.com")
  insert_invite_link_used(db, "il_used", "used@example.com")

  let missing_res =
    handler(simulate.request(http.Get, "/api/v1/auth/invite-links/il_missing"))

  expect.expect_status(missing_res, 403)
  string.contains(simulate.read_body(missing_res), "INVITE_INVALID")
  |> expect.is_true

  let invalidated_res =
    handler(simulate.request(
      http.Get,
      "/api/v1/auth/invite-links/il_invalidated",
    ))

  expect.expect_status(invalidated_res, 403)
  string.contains(simulate.read_body(invalidated_res), "INVITE_INVALID")
  |> expect.is_true

  let used_res =
    handler(simulate.request(http.Get, "/api/v1/auth/invite-links/il_used"))

  expect.expect_status(used_res, 403)
  string.contains(simulate.read_body(used_res), "INVITE_USED")
  |> expect.is_true
}

pub fn register_consumes_invite_once_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  insert_invite_link_active(db, "il_once", "first@example.com")

  let first_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_once")),
      ]),
    )

  let first_res = handler(first_req)
  expect.expect_status(first_res, 200)

  let second_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_once")),
      ]),
    )

  let second_res = handler(second_req)
  expect.expect_status(second_res, 403)
  string.contains(simulate.read_body(second_res), "INVITE_USED")
  |> expect.is_true
}

pub fn register_rejects_invalid_invalidated_and_used_invite_links_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  insert_invite_link_invalidated(
    db,
    "il_invalidated",
    "invalidated@example.com",
  )
  insert_invite_link_used(db, "il_used", "used@example.com")

  let invalid_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_missing")),
      ]),
    )

  let invalid_res = handler(invalid_req)
  expect.expect_status(invalid_res, 403)
  string.contains(simulate.read_body(invalid_res), "INVITE_INVALID")
  |> expect.is_true

  let invalidated_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_invalidated")),
      ]),
    )

  let invalidated_res = handler(invalidated_req)
  expect.expect_status(invalidated_res, 403)
  string.contains(simulate.read_body(invalidated_res), "INVITE_INVALID")
  |> expect.is_true

  let used_req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_used")),
      ]),
    )

  let used_res = handler(used_req)
  expect.expect_status(used_res, 403)
  string.contains(simulate.read_body(used_res), "INVITE_USED")
  |> expect.is_true
}

pub fn login_sets_session_and_csrf_cookies_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let res = login_response(handler)
  expect.expect_status(res, 200)

  let cookies = set_cookie_headers(res.headers)
  list.length(cookies) |> expect.equal(2)

  let has_session_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_session=")
      && string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Lax")
      && string.contains(h, "Path=/")
    })

  has_session_cookie |> expect.is_true

  let has_csrf_cookie =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_csrf=")
      && !string.contains(h, "HttpOnly")
      && string.contains(h, "Secure")
      && string.contains(h, "SameSite=Lax")
      && string.contains(h, "Path=/")
    })

  has_csrf_cookie |> expect.is_true
}

pub fn login_rejects_invalid_credentials_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/login")
      |> simulate.json_body(
        json.object([
          #("email", json.string("admin@example.com")),
          #("password", json.string("wrong-password")),
        ]),
      ),
    )

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn login_rejects_unknown_email_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/login")
      |> simulate.json_body(
        json.object([
          #("email", json.string("unknown@example.com")),
          #("password", json.string("passwordpassword")),
        ]),
      ),
    )

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn me_requires_auth_and_returns_user_when_authenticated_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let unauth_res = handler(simulate.request(http.Get, "/api/v1/auth/me"))
  expect.expect_status(unauth_res, 401)
  string.contains(simulate.read_body(unauth_res), "AUTH_REQUIRED")
  |> expect.is_true

  let session =
    fixtures.login(handler, "admin@example.com", "passwordpassword")
    |> expect.ok

  let authed_req =
    simulate.request(http.Get, "/api/v1/auth/me")
    |> fixtures.with_auth(session)

  let authed_res = handler(authed_req)
  expect.expect_status(authed_res, 200)
  string.contains(simulate.read_body(authed_res), "admin@example.com")
  |> expect.is_true
}

pub fn logout_clears_cookies_and_csrf_is_required_for_logout_mutation_test() {
  let #(_, handler, _) = fixtures.bootstrap() |> expect.ok

  let session =
    fixtures.login(handler, "admin@example.com", "passwordpassword")
    |> expect.ok

  let bad_req =
    simulate.request(http.Post, "/api/v1/auth/logout")
    |> request.set_cookie("sb_session", session.token)
    |> request.set_cookie("sb_csrf", session.csrf)

  let bad_res = handler(bad_req)
  expect.expect_status(bad_res, 403)
  list.length(set_cookie_headers(bad_res.headers)) |> expect.equal(0)

  let ok_req =
    simulate.request(http.Post, "/api/v1/auth/logout")
    |> fixtures.with_auth(session)

  let ok_res = handler(ok_req)
  expect.expect_status(ok_res, 204)

  let cookies = set_cookie_headers(ok_res.headers)
  list.length(cookies) |> expect.equal(2)

  let clears_session =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_session=")
      && string.contains(h, "Max-Age=0")
      && string.contains(h, "Expires=Thu, 01 Jan 1970")
    })

  clears_session |> expect.is_true

  let clears_csrf =
    cookies
    |> list.any(fn(h) {
      string.starts_with(h, "sb_csrf=")
      && string.contains(h, "Max-Age=0")
      && string.contains(h, "Expires=Thu, 01 Jan 1970")
    })

  clears_csrf |> expect.is_true
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

fn login_response(handler) {
  let req =
    simulate.request(http.Post, "/api/v1/auth/login")
    |> simulate.json_body(
      json.object([
        #("email", json.string("admin@example.com")),
        #("password", json.string("passwordpassword")),
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

fn insert_invite_link_invalidated(
  db: pog.Connection,
  token: String,
  email: String,
) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invite_links (org_id, email, token, created_by, invalidated_at) values (1, $1, $2, 1, now())",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)

  Nil
}

fn insert_invite_link_used(db: pog.Connection, token: String, email: String) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invite_links (org_id, email, token, created_by, used_at, used_by) values (1, $1, $2, 1, now(), 1)",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)

  Nil
}
