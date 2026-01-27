import fixtures
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/string
import gleeunit/should
import scrumbringer_server
import wisp
import wisp/simulate

fn create_card_req(project_id: Int, title: String, color: String) -> wisp.Request {
  simulate.request(
    http.Post,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
  )
  |> simulate.json_body(
    json.object([
      #("title", json.string(title)),
      #("description", json.string("desc")),
      #("color", json.string(color)),
    ]),
  )
}

pub fn create_card_requires_auth_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Core")

  let res = handler(create_card_req(project_id, "Card", "red"))
  res.status |> should.equal(401)
}

pub fn create_card_requires_csrf_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      create_card_req(project_id, "Card", "red")
      |> request.set_cookie("sb_session", session.token),
    )

  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> should.be_true
}

pub fn create_card_rejects_invalid_color_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      create_card_req(project_id, "Card", "beige")
      |> fixtures.with_auth(session),
    )

  res.status |> should.equal(422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> should.be_true
}

pub fn create_card_rejects_missing_title_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )

  res.status |> should.equal(422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> should.be_true
}

pub fn create_card_requires_project_admin_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Core")

  let assert Ok(member_id) =
    fixtures.create_member_user(handler, db, "member@example.com", "il_member")
  let assert Ok(Nil) =
    fixtures.add_member(handler, session, project_id, member_id, "member")

  let assert Ok(member_session) =
    fixtures.login(handler, "member@example.com", "passwordpassword")

  let res =
    handler(
      create_card_req(project_id, "Card", "red")
      |> fixtures.with_auth(member_session),
    )

  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> should.be_true
}

pub fn get_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/cards/999999")
      |> fixtures.with_auth(session),
    )

  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> should.be_true
}

pub fn update_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Patch, "/api/v1/cards/999999")
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Nope")),
          #("description", json.string("desc")),
          #("color", json.string("red")),
        ]),
      ),
    )

  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> should.be_true
}

pub fn delete_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Delete, "/api/v1/cards/999999")
      |> fixtures.with_auth(session),
    )

  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> should.be_true
}
