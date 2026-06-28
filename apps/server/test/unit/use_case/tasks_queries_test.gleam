//// Unit tests for task claim/release/close queries.
////
//// Tests the core task lifecycle operations via HTTP API with fixtures.
//// Uses fixtures.gleam for test setup and authentication.

import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleeunit
import pog
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/service_error
import scrumbringer_server/use_case/workflows/claimable_task
import support/assertions as expect
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC1: Claim success test
// =============================================================================

pub fn claim_task_succeeds_for_available_task_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Test Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

  expect.expect_status(res, 200)

  let assert Ok(status) =
    fixtures.query_string(db, task_status_query(), [pog.int(task_id)])
  status |> expect.equal("claimed")
}

// =============================================================================
// AC2: Claim conflict test
// =============================================================================

pub fn claim_task_fails_for_already_claimed_task_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Test Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(other_user_id) =
    fixtures.create_member_user(handler, db, "other@example.com", "inv_other")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")
  let assert Ok(other_session) =
    fixtures.login(handler, "other@example.com", "passwordpassword")

  let claim1_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim1_res, 200)

  let claim2_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(other_session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

  expect.expect_status(claim2_res, 409)
}

// =============================================================================
// AC3: Claim version mismatch test
// =============================================================================

pub fn claim_task_fails_with_version_mismatch_test() {
  let #(_db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Test Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(99))])),
    )

  expect.expect_status(res, 409)
}

pub fn claim_task_query_rejects_open_dependencies_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Blocked Query Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Blocked")
  let assert Ok(blocker_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Blocker")

  let assert Ok(user_id) =
    fixtures.query_int(db, "select id from users where email = $1", [
      pog.text("admin@example.com"),
    ])
  let assert Ok(org_id) =
    fixtures.query_int(db, "select org_id from users where id = $1", [
      pog.int(user_id),
    ])
  let assert Ok(_) =
    fixtures.query_int(
      db,
      "insert into task_dependencies (task_id, depends_on_task_id, created_by) values ($1, $2, $3) returning id",
      [pog.int(task_id), pog.int(blocker_id), pog.int(user_id)],
    )

  let assert Ok(task) = tasks_queries.get_task_for_user(db, task_id, user_id)
  let assert Ok(claimable) = claimable_task.from_task(db, task)
  let assert Error(service_error.NotFound) =
    tasks_queries.claim_task(db, org_id, claimable, user_id, 1)

  let assert Ok(status) =
    fixtures.query_string(db, task_status_query(), [pog.int(task_id)])
  status |> expect.equal("available")
}

// =============================================================================
// AC4: Release success test
// =============================================================================

pub fn release_task_succeeds_for_claimer_test() {
  let #(_db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Test Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim_res, 200)

  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  expect.expect_status(release_res, 200)
}

// =============================================================================
// AC5: Release auth test (non-claimer fails)
// =============================================================================

pub fn release_task_fails_for_non_claimer_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Test Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(other_user_id) =
    fixtures.create_member_user(handler, db, "other@example.com", "inv_other")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")
  let assert Ok(other_session) =
    fixtures.login(handler, "other@example.com", "passwordpassword")

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim_res, 200)

  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(other_session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  expect.expect_status(release_res, 403)
}

// =============================================================================
// AC6: Close success test
// =============================================================================

pub fn close_task_succeeds_for_claimer_test() {
  let #(_db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Test Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim_res, 200)

  let close_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/close",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  expect.expect_status(close_res, 200)
}

// =============================================================================
// AC7: Close auth test (non-claimer fails)
// =============================================================================

pub fn close_task_fails_for_non_claimer_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Test Project")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(other_user_id) =
    fixtures.create_member_user(handler, db, "other@example.com", "inv_other")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")
  let assert Ok(other_session) =
    fixtures.login(handler, "other@example.com", "passwordpassword")

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim_res, 200)

  let close_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/close",
      )
      |> fixtures.with_auth(other_session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  expect.expect_status(close_res, 403)
}

fn task_status_query() -> String {
  "SELECT execution_state FROM tasks WHERE id = $1"
}
