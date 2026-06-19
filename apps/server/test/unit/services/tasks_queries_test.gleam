//// Unit tests for task claim/release/complete queries.
////
//// Tests the core task lifecycle operations via HTTP API with fixtures.
//// Uses fixtures.gleam for test setup and authentication.

import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleeunit
import pog
import scrumbringer_server
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/service_error
import support/assertions as expect
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC1: Claim success test
// =============================================================================

pub fn claim_task_succeeds_for_available_task_test() {
  // Given: Bootstrap and create a project with a task
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // When: User claims the task with version 1
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

  // Then: Claim succeeds
  expect.expect_status(res, 200)

  // Verify task is now claimed
  let assert Ok(status) =
    fixtures.query_string(db, task_status_query(), [pog.int(task_id)])
  status |> expect.equal("claimed")
}

// =============================================================================
// AC2: Claim conflict test
// =============================================================================

pub fn claim_task_fails_for_already_claimed_task_test() {
  // Given: Bootstrap and create a task that is already claimed
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // Create a second user
  let assert Ok(other_user_id) =
    fixtures.create_member_user(handler, db, "other@example.com", "inv_other")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")
  let assert Ok(other_session) =
    fixtures.login(handler, "other@example.com", "passwordpassword")

  // First user claims the task
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

  // When: Second user tries to claim the same task
  let claim2_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(other_session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

  // Then: Claim fails with conflict
  expect.expect_status(claim2_res, 409)
}

// =============================================================================
// AC3: Claim version mismatch test
// =============================================================================

pub fn claim_task_fails_with_version_mismatch_test() {
  // Given: Bootstrap and create a task
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // When: User tries to claim with wrong version (task has version 1, we send 99)
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(99))])),
    )

  // Then: Claim fails with conflict (version mismatch)
  expect.expect_status(res, 409)
}

pub fn claim_task_query_rejects_incomplete_dependencies_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Blocked Query Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
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

  let assert Error(service_error.NotFound) =
    tasks_queries.claim_task(db, org_id, task_id, user_id, 1)

  let assert Ok(status) =
    fixtures.query_string(db, task_status_query(), [pog.int(task_id)])
  status |> expect.equal("available")
}

// =============================================================================
// AC4: Release success test
// =============================================================================

pub fn release_task_succeeds_for_claimer_test() {
  // Given: Bootstrap, create and claim a task
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // Claim the task first
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

  // When: Same user releases the task (version is now 2 after claim)
  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  // Then: Release succeeds
  expect.expect_status(release_res, 200)
}

// =============================================================================
// AC5: Release auth test (non-claimer fails)
// =============================================================================

pub fn release_task_fails_for_non_claimer_test() {
  // Given: Bootstrap, create and claim a task by user1
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // Create second user and add to project
  let assert Ok(other_user_id) =
    fixtures.create_member_user(handler, db, "other@example.com", "inv_other")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")
  let assert Ok(other_session) =
    fixtures.login(handler, "other@example.com", "passwordpassword")

  // First user claims the task
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

  // When: Second user (non-claimer) tries to release
  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(other_session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  // Then: Release fails with 403 Forbidden
  expect.expect_status(release_res, 403)
}

// =============================================================================
// AC6: Complete success test
// =============================================================================

pub fn complete_task_succeeds_for_claimer_test() {
  // Given: Bootstrap, create and claim a task
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // Claim the task first
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

  // When: Same user completes the task (version is now 2 after claim)
  let complete_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  // Then: Complete succeeds
  expect.expect_status(complete_res, 200)
}

// =============================================================================
// AC7: Complete auth test (non-claimer fails)
// =============================================================================

pub fn complete_task_fails_for_non_claimer_test() {
  // Given: Bootstrap, create and claim a task by user1
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // Create second user and add to project
  let assert Ok(other_user_id) =
    fixtures.create_member_user(handler, db, "other@example.com", "inv_other")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")
  let assert Ok(other_session) =
    fixtures.login(handler, "other@example.com", "passwordpassword")

  // First user claims the task
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

  // When: Second user (non-claimer) tries to complete
  let complete_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
      )
      |> fixtures.with_auth(other_session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  // Then: Complete fails with 403 Forbidden
  expect.expect_status(complete_res, 403)
}

fn task_status_query() -> String {
  "SELECT case when execution_state = 'closed' then 'completed' else execution_state end FROM tasks WHERE id = $1"
}
