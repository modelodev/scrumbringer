import fixtures
import gleam/http
import gleam/http/request
import gleam/json
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn non_admin_cannot_create_invite_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  fixtures.create_member_user(handler, db, "member@example.com", "il_member")
  |> expect.ok

  let member_session =
    fixtures.login(handler, "member@example.com", "passwordpassword")
    |> expect.ok

  let req =
    simulate.request(http.Post, "/api/v1/org/invites")
    |> fixtures.with_auth(member_session)
    |> simulate.json_body(json.object([]))

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn missing_csrf_is_rejected_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let req =
    simulate.request(http.Post, "/api/v1/org/invites")
    |> request.set_cookie("sb_session", session.token)
    |> request.set_cookie("sb_csrf", session.csrf)
    |> simulate.json_body(json.object([]))

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn create_invite_defaults_expiry_to_168_hours_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let req =
    simulate.request(http.Post, "/api/v1/org/invites")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([]))

  let res = handler(req)
  expect.expect_status(res, 200)

  let invite_code =
    fixtures.require_query_string(
      db,
      "select code from org_invites order by created_at desc limit 1",
      [],
    )

  let hours =
    fixtures.require_query_int(
      db,
      "select round(extract(epoch from (expires_at - created_at)) / 3600)::int from org_invites where code = $1",
      [pog.text(invite_code)],
    )

  hours |> expect.equal(168)

  let body = simulate.read_body(res)
  string.contains(body, "\"data\"") |> expect.is_true
  string.contains(body, "\"invite\"") |> expect.is_true
  string.contains(body, invite_code) |> expect.is_true
  string.contains(body, "created_at") |> expect.is_true
  string.contains(body, "expires_at") |> expect.is_true
}
