//// Unit tests for workflows_db CRUD and cascade operations.
////
//// Tests workflow create/update/delete operations and active cascade behavior.
//// Uses fixtures.gleam for test setup.

import fixtures
import gleam/option.{None}
import gleeunit
import gleeunit/should
import pog
import scrumbringer_server

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC1: Create workflow success test
// =============================================================================

pub fn create_workflow_succeeds_with_valid_data_test() {
  // Given: Bootstrap creates org with admin user
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create a project for project-scoped workflow test
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Workflow Test Project")

  // When: Create workflow via API
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Test Workflow")

  // Then: Workflow exists in database
  let assert Ok(count) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM workflows WHERE id = $1", [
      pog.int(workflow_id),
    ])
  count |> should.equal(1)

  // Verify workflow is active by default
  let assert Ok(active) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM workflows WHERE id = $1",
      [pog.int(workflow_id)],
    )
  active |> should.equal(1)
}

// =============================================================================
// AC2: Create workflow duplicate fails test
// =============================================================================

pub fn create_workflow_fails_for_duplicate_name_test() {
  // Given: Bootstrap and create a workflow
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Dup Test Project")
  let assert Ok(_workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Unique Workflow")

  // When: Try to create another workflow with same name (same project scope)
  let result =
    fixtures.create_workflow(handler, session, project_id, "Unique Workflow")

  // Then: Fails with error
  result |> should.be_error()
}

// =============================================================================
// AC3: Update workflow success test
// =============================================================================

pub fn update_workflow_succeeds_for_existing_workflow_test() {
  // Given: Bootstrap and create a workflow
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Update Test Project")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Original Name")

  // When: Update workflow via fixtures helper (deactivate it)
  let assert Ok(Nil) = fixtures.set_workflow_active(db, workflow_id, False)

  // Then: Workflow is now inactive
  let assert Ok(active) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM workflows WHERE id = $1",
      [pog.int(workflow_id)],
    )
  active |> should.equal(0)
}

// =============================================================================
// AC4: Set active cascade deactivates children test
// =============================================================================

pub fn set_active_cascade_deactivates_children_test() {
  // Given: Workflow with an active rule
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Cascade Test Project")
  let assert Ok(_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Cascade Workflow")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Test Rule",
      "completed",
    )

  // Verify rule is initially active
  let assert Ok(rule_active_before) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_active_before |> should.equal(1)

  // When: Deactivate workflow via API (cascades to rules)
  let assert Ok(Nil) =
    fixtures.set_workflow_active_cascade(handler, session, workflow_id, False)

  // Then: Rule is now inactive
  let assert Ok(rule_active_after) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_active_after |> should.equal(0)
}

pub fn set_active_cascade_activates_children_test() {
  // Given: Workflow and rule both inactive
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Activate Cascade Project")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Inactive Workflow")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Inactive Rule",
      "completed",
    )

  // Deactivate both using cascade API
  let assert Ok(Nil) =
    fixtures.set_workflow_active_cascade(handler, session, workflow_id, False)

  // Verify both are now inactive
  let assert Ok(rule_inactive) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_inactive |> should.equal(0)

  // When: Activate workflow via API (cascades to rules)
  let assert Ok(Nil) =
    fixtures.set_workflow_active_cascade(handler, session, workflow_id, True)

  // Then: Rule is now active
  let assert Ok(rule_active) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_active |> should.equal(1)
}

// =============================================================================
// AC5: Delete workflow cascade test
// =============================================================================

pub fn delete_workflow_succeeds_if_no_rules_test() {
  // Given: Workflow with no rules
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Delete Test Project")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "To Delete")

  // When: Delete workflow via API
  let assert Ok(Nil) = fixtures.delete_workflow(handler, session, workflow_id)

  // Then: Workflow no longer exists
  let assert Ok(count) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM workflows WHERE id = $1", [
      pog.int(workflow_id),
    ])
  count |> should.equal(0)
}

pub fn delete_workflow_cascades_deletes_rules_test() {
  // Given: Workflow with rules (FK ON DELETE CASCADE)
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Cascade Delete Project")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Workflow With Rules",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Rule To Delete",
      "completed",
    )

  // Verify rule exists
  let assert Ok(rule_count_before) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM rules WHERE id = $1", [
      pog.int(rule_id),
    ])
  rule_count_before |> should.equal(1)

  // When: Delete workflow (cascades to rules via FK)
  let assert Ok(Nil) = fixtures.delete_workflow(handler, session, workflow_id)

  // Then: Rule is also deleted
  let assert Ok(rule_count_after) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM rules WHERE id = $1", [
      pog.int(rule_id),
    ])
  rule_count_after |> should.equal(0)
}
