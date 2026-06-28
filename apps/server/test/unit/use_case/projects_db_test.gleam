//// Unit tests for project membership authorization.
////
//// Tests is_project_member and is_project_manager functions via HTTP API
//// using fixtures.gleam for test setup.

import fixtures
import gleeunit
import pog
import scrumbringer_server
import scrumbringer_server/use_case/authorization
import support/assertions as expect

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC3: Project member positive test
// =============================================================================

pub fn is_project_member_returns_true_for_member_test() {
  let #(db, _handler, _session, project_id) =
    fixtures.require_project_context("Member Test Project")

  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let result = authorization.is_project_member(db, user_id, project_id)

  result |> expect.is_true
}

// =============================================================================
// AC4: Project member negative test
// =============================================================================

pub fn is_project_member_returns_false_for_non_member_test() {
  let #(db, handler, _session, project_id) =
    fixtures.require_project_context("Non-Member Test Project")

  let assert Ok(other_user_id) =
    fixtures.create_member_user(
      handler,
      db,
      "outsider@example.com",
      "inv_outsider",
    )

  let result = authorization.is_project_member(db, other_user_id, project_id)

  result |> expect.is_false
}

// =============================================================================
// AC5: Project admin positive test
// =============================================================================

pub fn is_project_manager_returns_true_for_admin_test() {
  let #(db, _handler, _session, project_id) =
    fixtures.require_project_context("Admin Test Project")

  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let result = authorization.is_project_manager(db, user_id, project_id)

  result |> expect.is_true
}

// =============================================================================
// AC6: Project admin negative test
// =============================================================================

pub fn is_project_manager_returns_false_for_member_test() {
  let #(db, handler, session, project_id) =
    fixtures.require_project_context("Admin Negative Test Project")

  let assert Ok(member_user_id) =
    fixtures.create_member_user(handler, db, "member@example.com", "inv_member")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, member_user_id, "member")

  let result = authorization.is_project_manager(db, member_user_id, project_id)

  result |> expect.is_false
}

// =============================================================================
// AC7: Org admin role check
// =============================================================================

pub fn org_admin_role_correctly_identified_test() {
  let #(db, _handler) = org_context()

  let assert Ok(org_role) =
    fixtures.query_string(db, "SELECT org_role FROM users WHERE email = $1", [
      pog.text("admin@example.com"),
    ])

  org_role |> expect.equal("admin")
}

pub fn org_member_role_correctly_identified_test() {
  let #(db, handler) = org_context()

  let assert Ok(_) =
    fixtures.create_member_user(
      handler,
      db,
      "orgmember@example.com",
      "inv_orgmember",
    )

  let assert Ok(org_role) =
    fixtures.query_string(db, "SELECT org_role FROM users WHERE email = $1", [
      pog.text("orgmember@example.com"),
    ])

  org_role |> expect.equal("member")
}

fn org_context() {
  let app = fixtures.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  #(db, scrumbringer_server.handler(app))
}
