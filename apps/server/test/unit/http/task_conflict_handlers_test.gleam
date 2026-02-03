import fixtures
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/string
import gleeunit/should
import scrumbringer_server
import scrumbringer_server/http/tasks/conflict_handlers
import wisp
import wisp/simulate

fn claim_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
    )
    |> request.set_cookie("sb_session", session.token)
    |> request.set_cookie("sb_csrf", session.csrf)
    |> request.set_header("X-CSRF", session.csrf)
    |> simulate.json_body(json.object([#("version", json.int(version))])),
  )
}

fn complete_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
    )
    |> request.set_cookie("sb_session", session.token)
    |> request.set_cookie("sb_csrf", session.csrf)
    |> request.set_header("X-CSRF", session.csrf)
    |> simulate.json_body(json.object([#("version", json.int(version))])),
  )
}

pub fn handle_claim_conflict_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let res = conflict_handlers.handle_claim_conflict(db, 999_999, user_id)
  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> should.be_true
}

pub fn handle_claim_conflict_returns_conflict_for_available_task_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Available")

  let res = conflict_handlers.handle_claim_conflict(db, task_id, user_id)
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_VERSION") |> should.be_true
}

pub fn handle_claim_conflict_returns_claimed_conflict_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Claimed")

  claim_task(handler, session, task_id, 1).status |> should.equal(200)

  let res = conflict_handlers.handle_claim_conflict(db, task_id, user_id)
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED") |> should.be_true
}

pub fn handle_claim_conflict_returns_validation_for_completed_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Completed")

  claim_task(handler, session, task_id, 1).status |> should.equal(200)
  complete_task(handler, session, task_id, 2).status |> should.equal(200)

  let res = conflict_handlers.handle_claim_conflict(db, task_id, user_id)
  res.status |> should.equal(422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> should.be_true
}

pub fn handle_version_or_claim_conflict_forbidden_when_claimed_by_other_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Claimed")

  claim_task(handler, session, task_id, 1).status |> should.equal(200)

  let assert Ok(other_user_id) =
    fixtures.insert_user_db(db, 1, "member@example.com", "member")
  let assert Ok(Nil) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")

  let res =
    conflict_handlers.handle_version_or_claim_conflict(
      db,
      task_id,
      other_user_id,
    )

  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> should.be_true
}

pub fn handle_version_or_claim_conflict_returns_validation_for_available_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Available")

  let res =
    conflict_handlers.handle_version_or_claim_conflict(db, task_id, user_id)

  res.status |> should.equal(422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> should.be_true
}
