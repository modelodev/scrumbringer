//// Integration tests for the full task lifecycle.
////
//// Tests complete workflows: create -> claim -> complete
//// and create -> claim -> release -> claim (by different user).

import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleeunit
import gleeunit/should
import pog
import scrumbringer_server
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC8: Full lifecycle test (create -> claim -> complete)
// =============================================================================

pub fn full_lifecycle_create_claim_complete_test() {
  // Given: Bootstrap and create a project with a task type
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Lifecycle Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Feature",
      "sparkles",
    )

  // Step 1: Create a task
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Complete Me")

  // Verify task is in available status
  let assert Ok(status1) =
    fixtures.query_string(db, "SELECT status FROM tasks WHERE id = $1", [
      pog.int(task_id),
    ])
  status1 |> should.equal("available")

  // Step 2: Claim the task
  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  claim_res.status |> should.equal(200)

  // Verify task is now claimed
  let assert Ok(status2) =
    fixtures.query_string(db, "SELECT status FROM tasks WHERE id = $1", [
      pog.int(task_id),
    ])
  status2 |> should.equal("claimed")

  // Step 3: Complete the task (version is now 2 after claim)
  let complete_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  complete_res.status |> should.equal(200)

  // Verify task is now completed
  let assert Ok(status3) =
    fixtures.query_string(db, "SELECT status FROM tasks WHERE id = $1", [
      pog.int(task_id),
    ])
  status3 |> should.equal("completed")

  // Verify claimed_by is cleared on completion
  let assert Ok(claimed_by_cleared) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN claimed_by IS NULL THEN 1 ELSE 0 END FROM tasks WHERE id = $1",
      [pog.int(task_id)],
    )
  claimed_by_cleared |> should.equal(1)

  // Verify completed_at is set
  let assert Ok(completed_at_check) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN completed_at IS NOT NULL THEN 1 ELSE 0 END FROM tasks WHERE id = $1",
      [pog.int(task_id)],
    )
  completed_at_check |> should.equal(1)
}

// =============================================================================
// AC9: Release lifecycle test (create -> claim -> release -> claim by different user)
// =============================================================================

pub fn full_lifecycle_create_claim_release_claim_test() {
  // Given: Bootstrap and create a project
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Release Test Project")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")

  // Create a second user who will claim the task after release
  let assert Ok(user2_id) =
    fixtures.create_member_user(handler, db, "user2@example.com", "inv_user2")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, user2_id, "member")
  let assert Ok(session2) =
    fixtures.login(handler, "user2@example.com", "passwordpassword")

  // Step 1: Create a task
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Release Me")

  // Step 2: User 1 claims the task
  let claim1_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  claim1_res.status |> should.equal(200)

  // Verify claimed_by is user 1
  let assert Ok(user1_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(claimed_by1) =
    fixtures.query_int(db, "SELECT claimed_by FROM tasks WHERE id = $1", [
      pog.int(task_id),
    ])
  claimed_by1 |> should.equal(user1_id)

  // Step 3: User 1 releases the task (version is now 2 after claim)
  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  release_res.status |> should.equal(200)

  // Verify task is back to available
  let assert Ok(status_after_release) =
    fixtures.query_string(db, "SELECT status FROM tasks WHERE id = $1", [
      pog.int(task_id),
    ])
  status_after_release |> should.equal("available")

  // Step 4: User 2 claims the task (version is now 3 after release)
  let claim2_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session2)
      |> simulate.json_body(json.object([#("version", json.int(3))])),
    )
  claim2_res.status |> should.equal(200)

  // Verify claimed_by is now user 2
  let assert Ok(claimed_by2) =
    fixtures.query_int(db, "SELECT claimed_by FROM tasks WHERE id = $1", [
      pog.int(task_id),
    ])
  claimed_by2 |> should.equal(user2_id)

  // Verify task status is claimed
  let assert Ok(status_final) =
    fixtures.query_string(db, "SELECT status FROM tasks WHERE id = $1", [
      pog.int(task_id),
    ])
  status_final |> should.equal("claimed")
}
