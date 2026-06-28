import domain/org_role
import fixtures
import gleam/string
import pog
import scrumbringer_server
import scrumbringer_server/http/tasks/conflict_handlers
import support/assertions as expect
import wisp/simulate

pub fn handle_claim_conflict_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let res = conflict_handlers.handle_claim_conflict(db, 999_999, user_id)
  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn handle_claim_conflict_returns_conflict_for_available_task_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Available")

  let res = conflict_handlers.handle_claim_conflict(db, task_id, user_id)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_VERSION") |> expect.is_true
}

pub fn handle_claim_conflict_returns_open_dependency_message_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Blocked")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Blocked")
  let assert Ok(blocker_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Blocker")
  let assert Ok(_) =
    fixtures.query_int(
      db,
      "insert into task_dependencies (task_id, depends_on_task_id, created_by) values ($1, $2, $3) returning id",
      [pog.int(task_id), pog.int(blocker_id), pog.int(user_id)],
    )

  let res = conflict_handlers.handle_claim_conflict(db, task_id, user_id)
  let body = simulate.read_body(res)

  expect.expect_status(res, 409)
  string.contains(body, "CONFLICT_BLOCKED") |> expect.is_true
  string.contains(body, "Task has open dependencies") |> expect.is_true
  string.contains(body, "Task has incomplete dependencies") |> expect.is_false
}

pub fn handle_claim_conflict_returns_claimed_conflict_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Claimed")

  fixtures.claim_task_status(handler, session, task_id, 1)
  |> expect.equal(200)

  let res = conflict_handlers.handle_claim_conflict(db, task_id, user_id)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED") |> expect.is_true
}

pub fn handle_claim_conflict_returns_validation_for_closed_task_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Closed")

  fixtures.claim_task_status(handler, session, task_id, 1)
  |> expect.equal(200)
  fixtures.close_task_status(handler, session, task_id, 2)
  |> expect.equal(200)

  let res = conflict_handlers.handle_claim_conflict(db, task_id, user_id)
  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn handle_version_or_claim_conflict_forbidden_when_claimed_by_other_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Claimed")

  fixtures.claim_task_status(handler, session, task_id, 1)
  |> expect.equal(200)

  let assert Ok(other_user_id) =
    fixtures.insert_user_db(db, 1, "member@example.com", org_role.Member)
  let assert Ok(Nil) =
    fixtures.add_member(handler, session, project_id, other_user_id, "member")

  let res =
    conflict_handlers.handle_version_or_claim_conflict(
      db,
      task_id,
      other_user_id,
    )

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn handle_version_or_claim_conflict_returns_validation_for_available_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Available")

  let res =
    conflict_handlers.handle_version_or_claim_conflict(db, task_id, user_id)

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}
