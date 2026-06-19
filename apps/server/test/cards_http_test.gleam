import fixtures
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/string
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

fn create_card_req(
  project_id: Int,
  title: String,
  color: String,
) -> wisp.Request {
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
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res = handler(create_card_req(project_id, "Card", "red"))
  expect.expect_status(res, 401)
}

pub fn create_card_requires_csrf_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      create_card_req(project_id, "Card", "red")
      |> request.set_cookie("sb_session", session.token),
    )

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn create_card_rejects_invalid_color_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      create_card_req(project_id, "Card", "beige")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn create_card_rejects_missing_title_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn create_card_rejects_invalid_content_type_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.string_body("not-json"),
    )

  expect.expect_status(res, 415)
}

pub fn create_card_requires_project_admin_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

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

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn get_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/cards/999999")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn legacy_milestones_routes_return_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let project_route =
    handler(
      simulate.request(http.Get, "/api/v1/projects/1/milestones")
      |> fixtures.with_auth(session),
    )
  let item_route =
    handler(
      simulate.request(http.Get, "/api/v1/milestones/1")
      |> fixtures.with_auth(session),
    )
  let activate_route =
    handler(
      simulate.request(http.Post, "/api/v1/milestones/1/activate")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(project_route, 404)
  expect.expect_status(item_route, 404)
  expect.expect_status(activate_route, 404)
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

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn update_card_rejects_invalid_color_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  let _ =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task",
    )

  let res =
    handler(
      simulate.request(http.Patch, "/api/v1/cards/" <> int.to_string(card_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Card")),
          #("description", json.string("desc")),
          #("color", json.string("beige")),
        ]),
      ),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn delete_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Delete, "/api/v1/cards/999999")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn delete_card_conflict_when_tasks_exist_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  let _ =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task",
    )

  let res =
    handler(
      simulate.request(http.Delete, "/api/v1/cards/" <> int.to_string(card_id))
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_HAS_TASKS")
  |> expect.is_true
}
