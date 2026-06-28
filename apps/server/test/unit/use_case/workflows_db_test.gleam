//// Unit tests for workflows_db CRUD and cascade operations.
////
//// Tests workflow create/update/delete operations and active cascade behavior.
//// Uses fixtures.gleam for test setup.

import fixtures
import gleam/option.{None}
import gleeunit
import pog
import support/assertions as expect

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC1: Create workflow success test
// =============================================================================

pub fn create_workflow_succeeds_with_valid_data_test() {
  let #(db, handler, session, project_id) =
    fixtures.require_project_context("Workflow Test Project")

  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Test Workflow")

  let assert Ok(count) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM workflows WHERE id = $1", [
      pog.int(workflow_id),
    ])
  count |> expect.equal(1)

  let assert Ok(active) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM workflows WHERE id = $1",
      [pog.int(workflow_id)],
    )
  active |> expect.equal(1)
}

// =============================================================================
// AC2: Create workflow duplicate fails test
// =============================================================================

pub fn create_workflow_fails_for_duplicate_name_test() {
  let #(_db, handler, session, project_id) =
    fixtures.require_project_context("Dup Test Project")
  let assert Ok(_workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Unique Workflow")

  let result =
    fixtures.create_workflow(handler, session, project_id, "Unique Workflow")

  let assert Error(_) = result
}

// =============================================================================
// AC3: Update workflow success test
// =============================================================================

pub fn update_workflow_succeeds_for_existing_workflow_test() {
  let #(db, handler, session, project_id) =
    fixtures.require_project_context("Update Test Project")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Original Name")

  let assert Ok(Nil) = fixtures.set_workflow_active(db, workflow_id, False)

  let assert Ok(active) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM workflows WHERE id = $1",
      [pog.int(workflow_id)],
    )
  active |> expect.equal(0)
}

// =============================================================================
// AC4: Set active cascade deactivates children test
// =============================================================================

pub fn set_active_cascade_deactivates_children_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Cascade Test Project")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Cascade Workflow")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Test Rule",
      fixtures.task_closed_done(),
      template_id,
    )

  let assert Ok(rule_active_before) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_active_before |> expect.equal(1)

  let assert Ok(Nil) =
    fixtures.set_workflow_active_cascade(handler, session, workflow_id, False)

  let assert Ok(rule_active_after) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_active_after |> expect.equal(0)
}

pub fn set_active_cascade_activates_children_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Activate Cascade Project")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Inactive Workflow")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Inactive Rule",
      fixtures.task_closed_done(),
      template_id,
    )

  let assert Ok(Nil) =
    fixtures.set_workflow_active_cascade(handler, session, workflow_id, False)

  let assert Ok(rule_inactive) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_inactive |> expect.equal(0)

  let assert Ok(Nil) =
    fixtures.set_workflow_active_cascade(handler, session, workflow_id, True)

  let assert Ok(rule_active) =
    fixtures.query_int(
      db,
      "SELECT CASE WHEN active THEN 1 ELSE 0 END FROM rules WHERE id = $1",
      [pog.int(rule_id)],
    )
  rule_active |> expect.equal(1)
}

// =============================================================================
// AC5: Delete workflow cascade test
// =============================================================================

pub fn delete_workflow_succeeds_if_no_rules_test() {
  let #(db, handler, session, project_id) =
    fixtures.require_project_context("Delete Test Project")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "To Delete")

  let assert Ok(Nil) = fixtures.delete_workflow(handler, session, workflow_id)

  let assert Ok(count) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM workflows WHERE id = $1", [
      pog.int(workflow_id),
    ])
  count |> expect.equal(0)
}

pub fn delete_workflow_cascades_deletes_rules_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Cascade Delete Project")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
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
      fixtures.task_closed_done(),
      template_id,
    )

  let assert Ok(rule_count_before) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM rules WHERE id = $1", [
      pog.int(rule_id),
    ])
  rule_count_before |> expect.equal(1)

  let assert Ok(Nil) = fixtures.delete_workflow(handler, session, workflow_id)

  let assert Ok(rule_count_after) =
    fixtures.query_int(db, "SELECT COUNT(*)::int FROM rules WHERE id = $1", [
      pog.int(rule_id),
    ])
  rule_count_after |> expect.equal(0)
}
