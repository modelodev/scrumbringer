import domain/task/state as task_state
import fixtures
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option as opt
import gleam/string
import gleeunit
import scrumbringer_server
import scrumbringer_server/seed_db
import support/assertions as expect
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

pub fn start_rejects_unclaimed_task_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: _db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WS Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Unclaimed")

  let res = fixtures.start_work_session_response(handler, session, task_id)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED")
  |> expect.is_true
}

pub fn start_rejects_closed_task_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WS Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(task_id) =
    fixtures.insert_task_db(
      db,
      seed_db.TaskInsertOptions(
        project_id: project_id,
        type_id: type_id,
        title: "Closed",
        description: "Closed",
        priority: 3,
        execution_state: task_state.Closed(
          reason: task_state.ClosedByClaimant,
          closed_at: "NOW()",
          closed_by: user_id,
        ),
        created_by: user_id,
        card_id: opt.None,
        created_from_rule_id: opt.None,
        pool_lifetime_s: 0,
        due_date: opt.None,
        created_at: opt.None,
        last_entered_pool_at: opt.None,
      ),
    )

  let res = fixtures.start_work_session_response(handler, session, task_id)
  expect.expect_status(res, 409)
  let body = simulate.read_body(res)
  string.contains(body, "CONFLICT_INVALID_STATE") |> expect.is_true
  string.contains(body, "Task is closed") |> expect.is_true
  string.contains(body, "Task is completed") |> expect.is_false
}

pub fn start_returns_conflict_for_missing_task_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = fixtures.start_work_session_response(handler, session, 999_999)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED")
  |> expect.is_true
}

pub fn start_is_idempotent_when_session_exists_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WS Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Duplicate")

  fixtures.claim_task_status(handler, session, task_id, 1)
  |> expect.equal(200)

  let first_start =
    fixtures.start_work_session_response(handler, session, task_id)
  expect.expect_status(first_start, 200)

  let second_start =
    fixtures.start_work_session_response(handler, session, task_id)
  expect.expect_status(second_start, 200)
}

pub fn heartbeat_returns_not_found_without_session_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = fixtures.heartbeat_work_session_response(handler, session, 999_999)
  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn heartbeat_requires_auth_test() {
  let assert Ok(#(_app, handler, _session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
      |> simulate.json_body(json.object([#("task_id", json.int(1))])),
    )

  expect.expect_status(res, 401)
  string.contains(simulate.read_body(res), "AUTH_REQUIRED") |> expect.is_true
}

pub fn heartbeat_requires_csrf_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
      |> request.set_cookie("sb_session", session.token)
      |> simulate.json_body(json.object([#("task_id", json.int(1))])),
    )

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn heartbeat_requires_task_id_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR")
  |> expect.is_true
}

pub fn heartbeat_rejects_invalid_json_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
      |> fixtures.with_auth(session)
      |> simulate.string_body("{invalid")
      |> request.set_header("content-type", "application/json"),
    )

  expect.expect_status(res, 400)
}

pub fn pause_without_session_returns_ok_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = fixtures.pause_work_session_response(handler, session, 999_999)

  expect.expect_status(res, 200)
}

pub fn heartbeat_rate_limited_on_second_call_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WS Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Rate limit")

  fixtures.claim_task_status(handler, session, task_id, 1)
  |> expect.equal(200)

  let start_res =
    fixtures.start_work_session_response(handler, session, task_id)
  expect.expect_status(start_res, 200)

  let hb1 = fixtures.heartbeat_work_session_response(handler, session, task_id)
  expect.expect_status(hb1, 200)

  let hb2 = fixtures.heartbeat_work_session_response(handler, session, task_id)
  expect.expect_status(hb2, 429)
  string.contains(simulate.read_body(hb2), "RATE_LIMITED")
  |> expect.is_true
}
