//// Integration tests for rules engine triggering on task close.
////
//// These tests verify the CLOSE flow:
//// HTTP API -> handlers -> task close -> rules engine -> task creation
////
//// This is critical because the rules engine is called "fire and forget"
//// in handlers.gleam, so errors could be silently swallowed.

import domain/card as domain_card
import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

fn activate_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  card_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/activate",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([])),
  )
}

fn close_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  card_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/close",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([#("reason", json.string("manually_closed"))]),
    ),
  )
}

// =============================================================================
// Core Integration Test: Close Task -> Rules Fire -> Tasks Created
// =============================================================================

// Justification: large function kept intact to preserve cohesive logic.
/// Verifies that closing a task via HTTP API triggers rules and creates tasks.
/// This is the critical end-to-end test that validates the task close flow.
pub fn close_task_via_api_triggers_rules_and_creates_tasks_test() {
  // Given: A project with a rule that creates tasks when Bug is closed.
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
      "Review {{origin}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Closed",
      fixtures.task_closed_done(),
      template_id,
    )

  // Create the bug task that will trigger the rule
  let assert Ok(bug_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Fix Login Bug",
    )

  // Count tasks and rule_executions before close
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

  task_count_before |> expect.equal(0)
  exec_count_before |> expect.equal(0)

  // When: Claim and close the task via HTTP API
  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim_res, 200)

  let close_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/close",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  // Then: Task is closed.
  expect.expect_status(close_res, 200)

  // And: Rule was executed
  let assert Ok(exec_count_after) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  exec_count_after |> expect.equal(1)

  // And: Review task was created from template
  let assert Ok(task_count_after) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  task_count_after |> expect.equal(1)

  // And: The created task title contains the origin link
  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "SELECT title FROM tasks WHERE type_id = $1 ORDER BY id DESC LIMIT 1",
      [pog.int(review_type_id)],
    )
  string.contains(created_title, "[Task #" <> int.to_string(bug_task_id))
  |> expect.is_true
}

/// Verifies TaskCreated rules do not cascade from automation-created tasks.
pub fn task_created_rule_does_not_cascade_from_automation_created_task_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Task Created No Cascade")
  let assert Ok(task_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Created Task WF")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      task_type_id,
      "Follow-up {{origin}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "On Task Created",
      fixtures.task_available(),
      template_id,
    )

  let assert Ok(source_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      task_type_id,
      "Manual source task",
    )

  let assert Ok(created_by_rule_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(rule_id)],
    )
  created_by_rule_count |> expect.equal(1)

  let assert Ok(total_task_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(task_type_id)],
    )
  total_task_count |> expect.equal(2)

  let assert Ok(applied_execution_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1 AND outcome = 'applied'",
      [pog.int(rule_id)],
    )
  applied_execution_count |> expect.equal(1)

  let assert Ok(generated_task_id) =
    fixtures.query_int(
      db,
      "SELECT id FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(rule_id)],
    )
  let assert Ok(generated_task_applied_executions) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE task_id = $1 AND outcome = 'applied'",
      [pog.int(generated_task_id)],
    )
  generated_task_applied_executions |> expect.equal(0)

  let assert Ok(source_task_applied_executions) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE task_id = $1 AND outcome = 'applied'",
      [pog.int(source_task_id)],
    )
  source_task_applied_executions |> expect.equal(1)
}

/// Verifies claim and release task triggers fire from the HTTP lifecycle.
pub fn claim_and_release_via_api_trigger_matching_rules_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Claim Release Triggers")
  let assert Ok(source_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Source", "check")
  let assert Ok(other_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Other", "circle")
  let assert Ok(followup_type_id) =
    fixtures.create_task_type(
      handler,
      session,
      project_id,
      "Follow-up",
      "sparkles",
    )
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Lifecycle WF")
  let assert Ok(claim_template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      followup_type_id,
      "Claim follow-up",
    )
  let assert Ok(release_template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      followup_type_id,
      "Release follow-up",
    )
  let assert Ok(claim_rule_id) =
    fixtures.create_task_rule_with_trigger(
      handler,
      session,
      workflow_id,
      Some(source_type_id),
      "On Claim",
      "task_claimed",
      claim_template_id,
    )
  let assert Ok(release_rule_id) =
    fixtures.create_task_rule_with_trigger(
      handler,
      session,
      workflow_id,
      Some(source_type_id),
      "On Release",
      "task_released",
      release_template_id,
    )

  let assert Ok(source_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      source_type_id,
      "Source task",
    )
  let assert Ok(other_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      other_type_id,
      "Other task",
    )

  let source_claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(source_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(source_claim_res, 200)

  let assert Ok(claim_created_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(claim_rule_id)],
    )
  claim_created_count |> expect.equal(1)
  let assert Ok(release_created_before) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(release_rule_id)],
    )
  release_created_before |> expect.equal(0)

  let source_release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(source_task_id) <> "/release",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  expect.expect_status(source_release_res, 200)

  let assert Ok(release_created_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(release_rule_id)],
    )
  release_created_count |> expect.equal(1)

  let other_claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(other_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(other_claim_res, 200)

  let other_release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(other_task_id) <> "/release",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  expect.expect_status(other_release_res, 200)

  let assert Ok(claim_created_after_other_type) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(claim_rule_id)],
    )
  claim_created_after_other_type |> expect.equal(1)
  let assert Ok(release_created_after_other_type) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(release_rule_id)],
    )
  release_created_after_other_type |> expect.equal(1)

  let assert Ok(followup_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(followup_type_id)],
    )
  followup_count |> expect.equal(2)
}

/// Verifies that selecting another template replaces the rule template.
pub fn close_task_uses_latest_selected_template_test() {
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
    fixtures.create_workflow(handler, session, project_id, "Feature Closed WF")

  // Create 3 templates and select each one in turn.
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

  // Create rule and select templates.
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(feature_type_id),
      "Feature Closed",
      fixtures.task_closed_done(),
      template1_id,
    )
  let assert Ok(Nil) =
    fixtures.select_rule_template(handler, session, rule_id, template2_id)
  let assert Ok(Nil) =
    fixtures.select_rule_template(handler, session, rule_id, template3_id)

  let assert Ok(selected_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_templates WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  selected_count |> expect.equal(1)

  let assert Ok(selected_template_id) =
    fixtures.query_int(
      db,
      "SELECT template_id FROM rule_templates WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  selected_template_id |> expect.equal(template3_id)

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
  qa_count_before |> expect.equal(0)

  // Claim and close
  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(feature_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

  let close_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(feature_task_id) <> "/close",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )

  expect.expect_status(close_res, 200)

  // Then: one QA task was created from the selected template.
  let assert Ok(qa_count_after) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(qa_type_id)],
    )
  qa_count_after |> expect.equal(1)

  let assert Ok(created_title) =
    fixtures.query_string(db, "SELECT title FROM tasks WHERE type_id = $1", [
      pog.int(qa_type_id),
    ])
  created_title |> expect.equal("Code Review")
}

// Justification: large function kept intact to preserve cohesive logic.
/// Verifies idempotency: closing the same task twice doesn't create duplicate tasks.
pub fn closing_same_task_twice_is_idempotent_test() {
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
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Closed",
      fixtures.task_closed_done(),
      template_id,
    )

  let assert Ok(bug_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Bug to Fix",
    )

  // First close
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
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/close",
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
  review_count_after_first |> expect.equal(1)

  // Try to close again (should fail because task is already closed).
  let close_again_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/close",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(3))])),
    )

  // Should return 422 (invalid transition or version conflict) not create more tasks
  expect.expect_status(close_again_res, 422)

  // Count should still be 1
  let assert Ok(review_count_after_second) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count_after_second |> expect.equal(1)
}

/// Verifies that inactive rules don't create tasks when a task is closed via API.
pub fn inactive_rule_does_not_trigger_on_api_close_test() {
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
      "Task Closed",
      fixtures.task_closed_done(),
      template_id,
    )

  // Deactivate the rule
  let assert Ok(Nil) = fixtures.set_rule_active(db, rule_id, False)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  // Claim and close
  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )

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

  // No review tasks should be created (rule is inactive)
  let assert Ok(review_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count |> expect.equal(0)

  // No rule execution should be logged
  let assert Ok(exec_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  exec_count |> expect.equal(0)
}

/// Verifies card activation and closure rules fire from the HTTP lifecycle.
pub fn card_activate_and_close_via_api_trigger_matching_rules_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Card Trigger API")
  let assert Ok(followup_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Followup", "check")
  let assert Ok(activation_template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      followup_type_id,
      "Activation follow-up",
    )
  let assert Ok(close_template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      followup_type_id,
      "Close follow-up",
    )
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Trigger WF")
  let assert Ok(activation_rule_id) =
    fixtures.create_rule_card(
      handler,
      session,
      workflow_id,
      "Any Card Activated",
      domain_card.Active,
      activation_template_id,
    )
  let assert Ok(close_rule_id) =
    fixtures.create_rule_card_at_depth(
      handler,
      session,
      workflow_id,
      "Depth 2 Closed",
      domain_card.Closed,
      2,
      close_template_id,
    )

  let assert Ok(root_card_id) =
    fixtures.create_card(handler, session, project_id, "Root activation")
  expect.expect_status(activate_card(handler, session, root_card_id), 200)

  let assert Ok(activation_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(activation_rule_id)],
    )
  activation_count |> expect.equal(1)

  let assert Ok(root_close_id) =
    fixtures.create_card(handler, session, project_id, "Root close mismatch")
  expect.expect_status(close_card(handler, session, root_close_id), 200)

  let assert Ok(close_mismatch_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(close_rule_id)],
    )
  close_mismatch_count |> expect.equal(0)

  let assert Ok(parent_card_id) =
    fixtures.create_card(handler, session, project_id, "Parent")
  let assert Ok(child_card_id) =
    fixtures.create_child_card(
      handler,
      session,
      project_id,
      parent_card_id,
      "Child",
    )
  expect.expect_status(close_card(handler, session, child_card_id), 200)

  let assert Ok(close_match_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE created_from_rule_id = $1",
      [pog.int(close_rule_id)],
    )
  close_match_count |> expect.equal(0)

  let assert Ok(close_execution) =
    fixtures.fetch_rule_execution(db, close_rule_id, "card", child_card_id)
  close_execution.outcome |> expect.equal("suppressed")
  close_execution.suppression_reason
  |> expect.equal("target_no_longer_accepts_tasks")
  close_execution.created_task_id |> expect.equal(0)

  let assert Ok(followup_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(followup_type_id)],
    )
  followup_count |> expect.equal(1)
}

// =============================================================================
// Card Inheritance Tests
// =============================================================================

// Justification: large function kept intact to preserve cohesive logic.
/// Verifies that closing a task with a card creates child tasks with the same card.
pub fn close_task_with_card_creates_child_tasks_with_same_card_test() {
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
  expect.expect_status(activate_card(handler, session, card_id), 200)

  // Create workflow with rule and template
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Inherit WF")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review {{origin}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Closed",
      fixtures.task_closed_done(),
      template_id,
    )

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
  bug_card_id |> expect.equal(Some(card_id))

  // Claim and close the task
  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim_res, 200)

  let close_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/close",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  expect.expect_status(close_res, 200)

  // Verify rule was executed
  let assert Ok(exec_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM rule_executions WHERE rule_id = $1",
      [pog.int(rule_id)],
    )
  exec_count |> expect.equal(1)

  // Verify review task was created
  let assert Ok(review_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count |> expect.equal(1)

  // CRITICAL: Verify the created review task has the SAME card_id as the parent
  let assert Ok(created_card_id) =
    fixtures.query_nullable_int(
      db,
      "SELECT card_id FROM tasks WHERE type_id = $1 ORDER BY id DESC LIMIT 1",
      [pog.int(review_type_id)],
    )
  created_card_id |> expect.equal(Some(card_id))
}

/// Verifies that closing a task without a card creates child tasks without a card.
pub fn close_task_with_card_creates_child_tasks_in_same_card_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create project and task types.
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
      "Review {{origin}}",
    )
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Closed",
      fixtures.task_closed_done(),
      template_id,
    )

  // Create the bug task under a card.
  let assert Ok(bug_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Fix Bug With Card",
    )

  // Verify bug task has a card.
  let assert Ok(bug_card_id) =
    fixtures.query_nullable_int(db, "SELECT card_id FROM tasks WHERE id = $1", [
      pog.int(bug_task_id),
    ])
  let assert Some(card_id) = bug_card_id

  // Claim and close the task
  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(1))])),
    )
  expect.expect_status(claim_res, 200)

  let close_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(bug_task_id) <> "/close",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("version", json.int(2))])),
    )
  expect.expect_status(close_res, 200)

  // Verify review task was created
  let assert Ok(review_count) =
    fixtures.query_int(
      db,
      "SELECT count(*)::int FROM tasks WHERE type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count |> expect.equal(1)

  // CRITICAL: Verify the created review task inherits the same card.
  let assert Ok(created_card_id) =
    fixtures.query_nullable_int(
      db,
      "SELECT card_id FROM tasks WHERE type_id = $1 ORDER BY id DESC LIMIT 1",
      [pog.int(review_type_id)],
    )
  created_card_id |> expect.equal(Some(card_id))
}
