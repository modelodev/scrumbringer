//// Unit tests for project membership authorization.
////
//// Tests is_project_member and is_project_manager functions via HTTP API
//// using fixtures.gleam for test setup.

import fixtures
import gleeunit
import gleeunit/should
import pog
import scrumbringer_server
import scrumbringer_server/services/authorization

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC3: Project member positive test
// =============================================================================

pub fn is_project_member_returns_true_for_member_test() {
  // Given: Bootstrap and create a project
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Member Test Project")

  // Get the admin user ID (who is automatically a project member/admin)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // When: Check if user is member of the project
  let result = authorization.is_project_member(db, user_id, project_id)

  // Then: Returns True
  result |> should.be_true()
}

// =============================================================================
// AC4: Project member negative test
// =============================================================================

pub fn is_project_member_returns_false_for_non_member_test() {
  // Given: Bootstrap and create a project
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Non-Member Test Project")

  // Create a second user who is NOT added to the project
  let assert Ok(other_user_id) =
    fixtures.create_member_user(
      handler,
      db,
      "outsider@example.com",
      "inv_outsider",
    )
  // Note: We intentionally do NOT call add_member

  // When: Check if non-member user is member of the project
  let result = authorization.is_project_member(db, other_user_id, project_id)

  // Then: Returns False
  result |> should.be_false()
}

// =============================================================================
// AC5: Project admin positive test
// =============================================================================

pub fn is_project_manager_returns_true_for_admin_test() {
  // Given: Bootstrap and create a project (creator becomes admin)
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Admin Test Project")

  // Get the admin user ID (project creator is automatically admin)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // When: Check if user is admin of the project
  let result = authorization.is_project_manager(db, user_id, project_id)

  // Then: Returns True
  result |> should.be_true()
}

// =============================================================================
// AC6: Project admin negative test
// =============================================================================

pub fn is_project_manager_returns_false_for_member_test() {
  // Given: Bootstrap and create a project
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Admin Negative Test Project")

  // Create a second user and add as regular member (not admin)
  let assert Ok(member_user_id) =
    fixtures.create_member_user(handler, db, "member@example.com", "inv_member")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, member_user_id, "member")

  // When: Check if regular member is admin
  let result = authorization.is_project_manager(db, member_user_id, project_id)

  // Then: Returns False
  result |> should.be_false()
}

// =============================================================================
// AC7: Org admin role check
// =============================================================================

pub fn org_admin_role_correctly_identified_test() {
  // Given: Bootstrap creates an org admin user
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Get admin user's org_role from database
  let assert Ok(org_role) =
    fixtures.query_string(db, "SELECT org_role FROM users WHERE email = $1", [
      pog.text("admin@example.com"),
    ])

  // Then: org_role should be 'admin'
  org_role |> should.equal("admin")
}

pub fn org_member_role_correctly_identified_test() {
  // Given: Bootstrap and create a member user
  let assert Ok(#(app, handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create a member user via invite
  let assert Ok(_) =
    fixtures.create_member_user(
      handler,
      db,
      "orgmember@example.com",
      "inv_orgmember",
    )

  // Get member user's org_role from database
  let assert Ok(org_role) =
    fixtures.query_string(db, "SELECT org_role FROM users WHERE email = $1", [
      pog.text("orgmember@example.com"),
    ])

  // Then: org_role should be 'member'
  org_role |> should.equal("member")
}
