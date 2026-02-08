import fixtures
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/option as opt
import gleam/string
import gleeunit
import gleeunit/should
import scrumbringer_server
import scrumbringer_server/seed_db
import wisp
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

fn start_session_request(
  task_id: Int,
  session: fixtures.Session,
) -> wisp.Request {
  simulate.request(http.Post, "/api/v1/me/work-sessions/start")
  |> fixtures.with_auth(session)
  |> simulate.json_body(json.object([#("task_id", json.int(task_id))]))
}

fn heartbeat_request(task_id: Int, session: fixtures.Session) -> wisp.Request {
  simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
  |> fixtures.with_auth(session)
  |> simulate.json_body(json.object([#("task_id", json.int(task_id))]))
}

fn claim_task(
  handler: fixtures.Handler,
  session: fixtures.Session,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("version", json.int(version))])),
  )
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

  let res = handler(start_session_request(task_id, session))
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED")
  |> should.be_true
}

pub fn start_rejects_completed_task_test() {
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
        title: "Completed",
        description: "Done",
        priority: 3,
        status: "completed",
        created_by: user_id,
        claimed_by: opt.Some(user_id),
        card_id: opt.None,
        created_from_rule_id: opt.None,
        pool_lifetime_s: 0,
        created_at: opt.None,
        claimed_at: opt.None,
        completed_at: opt.None,
        last_entered_pool_at: opt.None,
      ),
    )

  let res = handler(start_session_request(task_id, session))
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_INVALID_STATE")
  |> should.be_true
}

pub fn start_returns_conflict_for_missing_task_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = handler(start_session_request(999_999, session))
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED")
  |> should.be_true
}

pub fn start_is_idempotent_when_session_exists_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WS Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Duplicate")

  let claim_res = claim_task(handler, session, task_id, 1)
  claim_res.status |> should.equal(200)

  let first_start = handler(start_session_request(task_id, session))
  first_start.status |> should.equal(200)

  let second_start = handler(start_session_request(task_id, session))
  second_start.status |> should.equal(200)
}

pub fn heartbeat_returns_not_found_without_session_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = handler(heartbeat_request(999_999, session))
  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> should.be_true
}

pub fn heartbeat_requires_auth_test() {
  let assert Ok(#(_app, handler, _session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
      |> simulate.json_body(json.object([#("task_id", json.int(1))])),
    )

  res.status |> should.equal(401)
  string.contains(simulate.read_body(res), "AUTH_REQUIRED") |> should.be_true
}

pub fn heartbeat_requires_csrf_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
      |> request.set_cookie("sb_session", session.token)
      |> simulate.json_body(json.object([#("task_id", json.int(1))])),
    )

  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> should.be_true
}

pub fn heartbeat_requires_task_id_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )

  res.status |> should.equal(422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR")
  |> should.be_true
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

  res.status |> should.equal(400)
}

pub fn pause_without_session_returns_ok_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/me/work-sessions/pause")
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("task_id", json.int(999_999))])),
    )

  res.status |> should.equal(200)
}

pub fn heartbeat_rate_limited_on_second_call_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WS Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Rate limit")

  let claim_res = claim_task(handler, session, task_id, 1)
  claim_res.status |> should.equal(200)

  let start_res = handler(start_session_request(task_id, session))
  start_res.status |> should.equal(200)

  let hb1 = handler(heartbeat_request(task_id, session))
  hb1.status |> should.equal(200)

  let hb2 = handler(heartbeat_request(task_id, session))
  hb2.status |> should.equal(429)
  string.contains(simulate.read_body(hb2), "RATE_LIMITED")
  |> should.be_true
}
