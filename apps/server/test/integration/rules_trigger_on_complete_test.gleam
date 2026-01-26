//// Integration tests for rules engine triggering on task completion.
////
//// These tests verify the COMPLETE flow:
//// HTTP API -> handlers -> task completion -> rules engine -> task creation
////
//// This is critical because the rules engine is called "fire and forget"
//// in handlers.gleam, so errors could be silently swallowed.

import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import pog
import scrumbringer_server
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// Core Integration Test: Complete Task -> Rules Fire -> Tasks Created
// =============================================================================

// Justification: large function kept intact to preserve cohesive logic.
/// Verifies that completing a task via HTTP API triggers rules and creates tasks.
/// This is the critical end-to-end test that validates the complete flow.
pub fn complete_task_via_api_triggers_rules_and_creates_tasks_test() {
  // Given: A project with a rule that creates tasks when Bug is completed
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create project and task types
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Rules Trigger Test")
  let assert Ok(bug_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(review_type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Review",
      "magnifier",
    )

  // Create workflow with rule and template
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Auto Review WF")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review {{father}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Complete",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  // Create the bug task that will trigger the rule
  let assert Ok(bug_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Fix Login Bug",
    )

  // Count tasks and rule_executions before completion
  let assert Ok(task_count_before) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  let assert Ok(exec_count_before) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1",
      [pog.int(rule_id)],
    )

  task_count_before |> should.equal(0)
  exec_count_before |> should.equal(0)

  // When: Claim and complete the task via HTTP API
  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  claim_res.status |> should.equal(200)

  let complete_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  // Then: Task is completed
  complete_res.status |> should.equal(200)

  // And: Rule was executed
  let assert Ok(exec_count_after) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  exec_count_after |> should.equal(1)

  // And: Review task was created from template
  let assert Ok(task_count_after) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  task_count_after |> should.equal(1)

  // And: The created task title contains the father link
  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "SELECT title FROM tasks WHERE type_id = $1 ORDER BY id DESC LIMIT 1",
      [pog.int(review_type_id)],
    )
  string.contains(created_title, "[Task #" <> int.to_string(bug_task_id))
  |> should.be_true
}

// Justification: large function kept intact to preserve cohesive logic.
/// Verifies that multiple templates attached to a rule create multiple tasks.
pub fn complete_task_with_multiple_templates_creates_all_tasks_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Multi Template Test")
  let assert Ok(feature_type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Feature",
      "sparkles",
    )
  let assert Ok(qa_type_id) =
    fixtures.create_task_type(handler, session, project_id, "QA", "magnifier")

  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Feature Complete WF",
    )

  // Create 3 templates
  let assert Ok(template1_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      qa_type_id,
      "QA Verification",
    )
  let assert Ok(template2_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      qa_type_id,
      "Deploy to Staging",
    )
  let assert Ok(template3_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      qa_type_id,
      "Code Review",
    )

  // Create rule and attach all templates
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(feature_type_id),
      "Feature Done",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template1_id)
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template2_id)
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template3_id)

  // Create feature task
  let assert Ok(feature_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      feature_type_id,
      "Implement Dark Mode",
    )

  let assert Ok(qa_count_before) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(qa_type_id)],
    )
  qa_count_before |> should.equal(0)

  // Claim and complete
  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(feature_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

  let complete_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(feature_task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  complete_res.status |> should.equal(200)

  // Then: 3 QA tasks were created
  let assert Ok(qa_count_after) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(qa_type_id)],
    )
  qa_count_after |> should.equal(3)
}

// Justification: large function kept intact to preserve cohesive logic.
/// Verifies idempotency: completing the same task twice doesn't create duplicate tasks.
pub fn completing_same_task_twice_is_idempotent_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Idempotent Test")
  let assert Ok(bug_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(review_type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Review",
      "magnifier",
    )

  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Idempotent WF")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review Task",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Complete",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  let assert Ok(bug_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Bug to Fix",
    )

  // First completion
  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  let assert Ok(review_count_after_first) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count_after_first |> should.equal(1)

  // Try to complete again (should fail because task is already completed)
  let complete_again_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(3))])),
    )

  // Should return 422 (invalid transition or version conflict) not create more tasks
  complete_again_res.status |> should.equal(422)

  // Count should still be 1
  let assert Ok(review_count_after_second) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count_after_second |> should.equal(1)
}

/// Verifies that inactive rules don't create tasks when task is completed via API.
pub fn inactive_rule_does_not_trigger_on_api_complete_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Inactive Rule API Test")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(review_type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Review",
      "magnifier",
    )

  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Inactive Rule WF")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Task Done",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  // Deactivate the rule
  let assert Ok(Nil) = fixtures.set_rule_active(db, rule_id, False)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // Claim and complete
  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

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

  // No review tasks should be created (rule is inactive)
  let assert Ok(review_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count |> should.equal(0)

  // No rule execution should be logged
  let assert Ok(exec_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  exec_count |> should.equal(0)
}

// =============================================================================
// Card Inheritance Tests
// =============================================================================

// Justification: large function kept intact to preserve cohesive logic.
/// Verifies that completing a task with a card creates child tasks with the same card.
pub fn complete_task_with_card_creates_child_tasks_with_same_card_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create project, task types, and a card
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Card Inheritance Test")
  let assert Ok(bug_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(review_type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Review",
      "magnifier",
    )
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Feature Card")

  // Create workflow with rule and template
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Inherit WF")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review {{father}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Complete",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  // Create the bug task WITH the card
  let assert Ok(bug_task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      bug_type_id,
      card_id,
      "Fix Login Bug",
    )

  // Verify bug task has the card
  let assert Ok(bug_card_id) =
    fixtures.query_nullable_int(db, "SELECT card_id FROM tasks WHERE id = $1", [
      pog.int(bug_task_id),
    ])
  bug_card_id |> should.equal(Some(card_id))

  // Claim and complete the task
  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  claim_res.status |> should.equal(200)

  let complete_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  complete_res.status |> should.equal(200)

  // Verify rule was executed
  let assert Ok(exec_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  exec_count |> should.equal(1)

  // Verify review task was created
  let assert Ok(review_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count |> should.equal(1)

  // CRITICAL: Verify the created review task has the SAME card_id as the parent
  let assert Ok(created_card_id) =
    fixtures.query_nullable_int(
      db,
      "SELECT card_id FROM tasks WHERE type_id = $1 ORDER BY id DESC LIMIT 1",
      [pog.int(review_type_id)],
    )
  created_card_id |> should.equal(Some(card_id))
}

/// Verifies that completing a task without a card creates child tasks without a card.
pub fn complete_task_without_card_creates_child_tasks_without_card_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create project and task types (no card)
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "No Card Test")
  let assert Ok(bug_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(review_type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Review",
      "magnifier",
    )

  // Create workflow with rule and template
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "No Card WF")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review {{father}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Complete",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  // Create the bug task WITHOUT a card
  let assert Ok(bug_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Fix Bug No Card",
    )

  // Verify bug task has no card
  let assert Ok(bug_card_id) =
    fixtures.query_nullable_int(db, "SELECT card_id FROM tasks WHERE id = $1", [
      pog.int(bug_task_id),
    ])
  bug_card_id |> should.equal(None)

  // Claim and complete the task
  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  claim_res.status |> should.equal(200)

  let complete_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  complete_res.status |> should.equal(200)

  // Verify review task was created
  let assert Ok(review_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count |> should.equal(1)

  // CRITICAL: Verify the created review task has NO card
  let assert Ok(created_card_id) =
    fixtures.query_nullable_int(
      db,
      "SELECT card_id FROM tasks WHERE type_id = $1 ORDER BY id DESC LIMIT 1",
      [pog.int(review_type_id)],
    )
  created_card_id |> should.equal(None)
}
