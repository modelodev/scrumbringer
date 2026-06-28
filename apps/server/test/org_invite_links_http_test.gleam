import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn non_admin_forbidden_for_invite_links_test() {
  let #(app, handler, _) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  fixtures.create_member_user(handler, db, "member@example.com", "il_member")
  |> expect.ok

  let member_session =
    fixtures.login(handler, "member@example.com", "passwordpassword")
    |> expect.ok

  let create_req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(member_session)
    |> simulate.json_body(json.object([#("email", json.string("a@b.com"))]))

  let create_res = handler(create_req)
  expect.expect_status(create_res, 403)

  let list_req =
    simulate.request(http.Get, "/api/v1/org/invite-links")
    |> fixtures.with_auth(member_session)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 403)
}

pub fn missing_csrf_is_rejected_for_create_and_regenerate_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let create_req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> request.set_cookie("sb_session", session.token)
    |> request.set_cookie("sb_csrf", session.csrf)
    |> simulate.json_body(json.object([#("email", json.string("a@b.com"))]))

  let create_res = handler(create_req)
  expect.expect_status(create_res, 403)

  let regen_req =
    simulate.request(http.Post, "/api/v1/org/invite-links/regenerate")
    |> request.set_cookie("sb_session", session.token)
    |> request.set_cookie("sb_csrf", session.csrf)
    |> simulate.json_body(json.object([#("email", json.string("a@b.com"))]))

  let regen_res = handler(regen_req)
  expect.expect_status(regen_res, 403)
}

pub fn create_invalidates_previous_active_token_for_email_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let email = "User@Example.com"

  let req1 =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  let res1 = handler(req1)
  expect.expect_status(res1, 200)

  let token1 =
    fixtures.require_query_string(
      db,
      "select token from org_invite_links where email = $1 order by created_at desc limit 1",
      [pog.text("user@example.com")],
    )

  let req2 =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  let res2 = handler(req2)
  expect.expect_status(res2, 200)

  let token2 =
    fixtures.require_query_string(
      db,
      "select token from org_invite_links where email = $1 and invalidated_at is null and used_at is null order by created_at desc limit 1",
      [pog.text("user@example.com")],
    )

  let same = token1 == token2
  same |> expect.is_false

  let invalidated =
    fixtures.require_query_int(
      db,
      "select (invalidated_at is not null)::int from org_invite_links where token = $1",
      [pog.text(token1)],
    )

  invalidated |> expect.equal(1)
}

pub fn list_sorted_by_email_asc_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let create = fn(email) {
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("email", json.string(email))]))
    |> handler
  }

  expect.expect_status(create("b@example.com"), 200)
  expect.expect_status(create("a@example.com"), 200)

  let list_req =
    simulate.request(http.Get, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)

  let res = handler(list_req)
  expect.expect_status(res, 200)

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

  emails |> expect.equal(["a@example.com", "b@example.com"])
}

pub fn no_time_expiry_links_stay_active_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let email = "old@example.com"

  let req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  let res = handler(req)
  expect.expect_status(res, 200)

  let token =
    fixtures.require_query_string(
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
    |> fixtures.with_auth(session)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)

  string.contains(simulate.read_body(list_res), "\"state\":\"active\"")
  |> expect.is_true
}

pub fn regenerate_creates_new_token_and_invalidates_previous_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let email = "regen@example.com"

  let create_req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  expect.expect_status(handler(create_req), 200)

  let token1 =
    fixtures.require_query_string(
      db,
      "select token from org_invite_links where email = $1 and invalidated_at is null and used_at is null order by created_at desc limit 1",
      [pog.text(email)],
    )

  let regen_req =
    simulate.request(http.Post, "/api/v1/org/invite-links/regenerate")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("email", json.string(email))]))

  expect.expect_status(handler(regen_req), 200)

  let token2 =
    fixtures.require_query_string(
      db,
      "select token from org_invite_links where email = $1 and invalidated_at is null and used_at is null order by created_at desc limit 1",
      [pog.text(email)],
    )

  let same = token1 == token2
  same |> expect.is_false

  fixtures.require_query_int(
    db,
    "select (invalidated_at is not null)::int from org_invite_links where token = $1",
    [pog.text(token1)],
  )
  |> expect.equal(1)
}

pub fn invalid_email_returns_422_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let req =
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([#("email", json.string("not-an-email"))]),
    )

  let res = handler(req)
  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn list_includes_invalidated_links_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let email = "inv@example.com"

  let create = fn() {
    simulate.request(http.Post, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("email", json.string(email))]))
    |> handler
  }

  expect.expect_status(create(), 200)
  expect.expect_status(create(), 200)

  let list_req =
    simulate.request(http.Get, "/api/v1/org/invite-links")
    |> fixtures.with_auth(session)

  let res = handler(list_req)
  expect.expect_status(res, 200)

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
  has_invalidated |> expect.is_true
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
