//// Integration tests for the rules engine.
////
//// Tests rule evaluation, idempotency, and task creation from templates.
//// Uses shared fixtures for DRY and idiomatic Result handling.

import fixtures
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import pog
import scrumbringer_server
import scrumbringer_server/services/rules_engine.{
  Applied, RuleResult, Suppressed,
}

// =============================================================================
// Core Engine Tests
// =============================================================================

pub fn evaluate_rules_creates_tasks_from_templates_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create project and task types
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Engineering")
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

  // Create workflow with template and rule
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Auto QA")
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
      "Bug Completed",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  // Get org_id and user_id for the event
  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Create a task to complete
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Fix Login Bug",
    )

  // Fire the event
  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(bug_type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(1))]) = result

  // Verify the Review task was created
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  count |> should.equal(1)
}

pub fn evaluate_rules_idempotency_suppresses_duplicate_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Idempotent")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Feature", "star")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Idempotent WF")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Feature Done",
      "completed",
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Build Feature")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  // First evaluation
  let result1 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(_))]) = result1

  // Second evaluation - should be suppressed
  let result2 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(rule_id: rid, outcome: Suppressed("idempotent"))]) =
    result2
  rid |> should.equal(rule_id)
}

pub fn evaluate_rules_skips_non_user_triggered_events_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "NonUser")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Auto WF")
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "System Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Event with user_triggered = False
  let event =
    fixtures.task_event_full(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
      False,
      None,
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([]) = result
}

pub fn evaluate_rules_card_resource_type_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Card Test")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Workflow")
  let assert Ok(_rule_id) =
    fixtures.create_rule_card(
      handler,
      session,
      workflow_id,
      "Card Closed",
      "closed",
    )
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Test Card")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.card_event(
      card_id,
      project_id,
      org_id,
      user_id,
      Some("open"),
      "closed",
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(0))]) = result
}

// =============================================================================
// Variable Substitution Tests
// =============================================================================

pub fn variable_father_task_resolves_to_link_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "FatherTask")
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
    fixtures.create_workflow(handler, session, project_id, "Father Task Test")
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      review_type_id,
      "Review {{father}}",
      "Desc for {{father}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Done",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, bug_type_id, "Login Bug")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(bug_type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Verify the created task title contains the father link
  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where type_id = $1 order by id desc limit 1",
      [pog.int(review_type_id)],
    )

  created_title
  |> string.contains("[Task #" <> int.to_string(task_id))
  |> should.be_true

  created_title
  |> string.contains("/tasks/" <> int.to_string(task_id) <> ")")
  |> should.be_true

  // Verify description also has the link
  let assert Ok(created_desc) =
    fixtures.query_string(
      db,
      "select description from tasks where type_id = $1 order by id desc limit 1",
      [pog.int(review_type_id)],
    )

  created_desc
  |> string.contains("[Task #" <> int.to_string(task_id))
  |> should.be_true
}

pub fn variable_father_card_resolves_to_link_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "CardVarTest")
  let assert Ok(task_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Father Test")
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      task_type_id,
      "Followup for {{father}}",
      "Card {{father}} was closed",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule_card(
      handler,
      session,
      workflow_id,
      "Card Closed",
      "closed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card to Close")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.card_event(
      card_id,
      project_id,
      org_id,
      user_id,
      Some("open"),
      "closed",
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks order by id desc limit 1",
      [],
    )

  created_title
  |> string.contains("[Card #" <> int.to_string(card_id))
  |> should.be_true

  created_title
  |> string.contains("/cards/" <> int.to_string(card_id) <> ")")
  |> should.be_true
}

pub fn variable_from_state_resolves_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "FromState")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "From State Test")
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      type_id,
      "{{from_state}} -> {{to_state}}",
      "Changed from {{from_state}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Original Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'claimed -> completed'",
      [],
    )

  created_title |> should.equal("claimed -> completed")
}

pub fn variable_from_state_null_shows_created_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "NullFromState")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Null From State Test",
    )
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      type_id,
      "From: {{from_state}}",
      "Was {{from_state}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "On Create",
      "available",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "New Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Task creation event (from_state is None)
  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      None,
      "available",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'From: (created)'",
      [],
    )

  created_title |> should.equal("From: (created)")

  let assert Ok(created_desc) =
    fixtures.query_string(
      db,
      "select description from tasks where title = 'From: (created)'",
      [],
    )

  created_desc |> should.equal("Was (created)")
}

pub fn variable_project_resolves_to_name_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "My Project Name")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Project Var Test")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "Task for {{project}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Trigger Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'Task for My Project Name'",
      [],
    )

  created_title |> should.equal("Task for My Project Name")
}

/// {{user}} resolves to the user's email address.
pub fn variable_user_resolves_to_email_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "UserVar")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "User Var Test")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "Done by {{user}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "User Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'Done by admin@example.com'",
      [],
    )

  // {{user}} resolves to email
  created_title |> should.equal("Done by admin@example.com")
}

// Justification: large function kept intact to preserve cohesive logic.
/// Tests all 5 variables in one template.
pub fn all_five_variables_combined_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create project and task types
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "CombinedVars")
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

  // Create workflow with template and rule
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Auto QA Combined")
  // Note: title must be ≤56 chars after variable substitution
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      review_type_id,
      "{{father}} ({{project}})",
      "{{user}}: {{from_state}}->{{to_state}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Completed",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  // Get org_id and user_id for the event
  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Create a task to complete
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      bug_type_id,
      "Fix Combined Bug",
    )

  // Fire the event
  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(bug_type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(1))]) = result

  // Verify the Review task was created (query by type_id to avoid flakiness)
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  count |> should.equal(1)

  // Verify title has {{father}}, {{project}} (query by type_id)
  let assert Ok(created_title) =
    fixtures.query_string(db, "select title from tasks where type_id = $1", [
      pog.int(review_type_id),
    ])

  created_title
  |> string.contains("[Task #" <> int.to_string(task_id))
  |> should.be_true
  created_title |> string.contains("CombinedVars") |> should.be_true

  // Verify description has {{user}}, {{from_state}}, {{to_state}} (query by type_id)
  let assert Ok(created_desc) =
    fixtures.query_string(
      db,
      "select description from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  created_desc |> string.contains("admin@example.com") |> should.be_true
  created_desc |> string.contains("claimed") |> should.be_true
  created_desc |> string.contains("completed") |> should.be_true
}

// =============================================================================
// Positive Tests
// =============================================================================

pub fn multiple_templates_create_multiple_tasks_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "MultiTemplate")
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
    fixtures.create_workflow(handler, session, project_id, "Multi Template WF")

  // Create 3 templates
  let assert Ok(template1_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review 1",
    )
  let assert Ok(template2_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review 2",
    )
  let assert Ok(template3_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      review_type_id,
      "Review 3",
    )

  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Done",
      "completed",
    )

  // Attach all 3 templates
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template1_id)
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template2_id)
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template3_id)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, bug_type_id, "Bug Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(bug_type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(3))]) = result

  // Verify 3 Review tasks were created (query by type_id)
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  count |> should.equal(3)
}

pub fn rule_without_task_type_matches_all_types_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "NoTypeFilter")
  let assert Ok(bug_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(feature_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Feature", "star")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "No Filter WF")

  // Rule without task_type_id filter
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Create and trigger Bug task
  let assert Ok(bug_task_id) =
    fixtures.create_task(handler, session, project_id, bug_type_id, "Bug Task")

  let bug_event =
    fixtures.task_event(
      bug_task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(bug_type_id),
    )

  let bug_result = rules_engine.evaluate_rules(db, bug_event)
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(_))]) = bug_result

  // Create and trigger Feature task
  let assert Ok(feature_task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      feature_type_id,
      "Feature Task",
    )

  let feature_event =
    fixtures.task_event(
      feature_task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(feature_type_id),
    )

  let feature_result = rules_engine.evaluate_rules(db, feature_event)
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(_))]) = feature_result
}

// =============================================================================
// Negative Tests
// =============================================================================

pub fn inactive_workflow_does_not_fire_rules_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "InactiveWF")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Inactive Workflow")

  // Deactivate workflow
  let assert Ok(Nil) = fixtures.set_workflow_active(db, workflow_id, False)

  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([]) = result
}

pub fn inactive_rule_does_not_fire_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "InactiveRule")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Active WF Inactive Rule",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Inactive Rule",
      "completed",
    )

  // Deactivate rule
  let assert Ok(Nil) = fixtures.set_rule_active(db, rule_id, False)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([]) = result
}

pub fn wrong_task_type_does_not_match_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WrongType")
  let assert Ok(bug_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(feature_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Feature", "star")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Type Filter WF")

  // Rule only matches Bug type
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Only",
      "completed",
    )

  // Create Feature task
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      feature_type_id,
      "Feature Task",
    )

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(feature_type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([]) = result
}

pub fn wrong_to_state_does_not_match_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "WrongState")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "State Filter WF")

  // Rule only matches 'completed' state
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "On Complete",
      "completed",
    )

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Event with 'claimed' state (not 'completed')
  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("available"),
      "claimed",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([]) = result
}

pub fn project_scoped_workflow_does_not_apply_to_other_project_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create two projects
  let assert Ok(project1_id) =
    fixtures.create_project(handler, session, "Project One")
  let assert Ok(project2_id) =
    fixtures.create_project(handler, session, "Project Two")

  let assert Ok(_type1_id) =
    fixtures.create_task_type(handler, session, project1_id, "Task", "check")
  let assert Ok(type2_id) =
    fixtures.create_task_type(handler, session, project2_id, "Task", "check")

  // Workflow scoped to Project One
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project1_id, "Project One WF")
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )

  // Task in Project Two
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project2_id,
      type2_id,
      "Project Two Task",
    )

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project2_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type2_id),
    )

  // Rule from Project One should not match task in Project Two
  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([]) = result
}

pub fn task_rule_does_not_fire_for_card_event_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "TaskOnlyRule")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Task Rule WF")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")

  // Rule for TASK resource_type
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Task Done",
      "completed",
    )
  let assert Ok(Nil) =
    fixtures.attach_template(handler, session, rule_id, template_id)

  // Create a card
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card Not Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(initial_count) =
    fixtures.query_int(db, "select count(*)::int from tasks", [])

  // CARD event (not task)
  let event =
    fixtures.card_event(
      card_id,
      project_id,
      org_id,
      user_id,
      Some("open"),
      "completed",
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Task rule should not match card event
  let assert Ok([]) = result

  let assert Ok(final_count) =
    fixtures.query_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count)
}

// =============================================================================
// AC13: Rule Executions Persistence Tests
// =============================================================================

/// Verify that applied rule executions are persisted to rule_executions table
/// with outcome='applied' and no suppression_reason.
pub fn rule_execution_applied_is_persisted_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "PersistApplied")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Feature", "star")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Persist Test WF")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Feature Done",
      "completed",
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Feature")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(initial_count) =
    fixtures.query_int(db, "select count(*)::int from rule_executions", [])

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(_, Applied(_))]) = result

  // Verify execution was persisted
  let assert Ok(final_count) =
    fixtures.query_int(db, "select count(*)::int from rule_executions", [])
  final_count |> should.equal(initial_count + 1)

  // Verify execution details using typed helper
  let assert Ok(execution) =
    fixtures.fetch_rule_execution(db, rule_id, "task", task_id)

  execution.outcome |> should.equal("applied")
  execution.suppression_reason |> should.equal("")
}

/// Verify that idempotency is enforced via rule_executions table.
pub fn rule_execution_idempotency_enforced_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "IdempotencyTest")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Idempotency Test WF",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Bug Fix")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event(
      task_id,
      project_id,
      org_id,
      user_id,
      Some("claimed"),
      "completed",
      Some(type_id),
    )

  // First fire (applied)
  let result1 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(_, Applied(_))]) = result1

  let assert Ok(execution_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from rule_executions where rule_id = $1",
      [pog.int(rule_id)],
    )
  execution_count |> should.equal(1)

  // Second fire (suppressed)
  let result2 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(_, Suppressed("idempotent"))]) = result2

  // Count remains 1 (unique constraint)
  let assert Ok(execution_count_after) =
    fixtures.query_int(
      db,
      "select count(*)::int from rule_executions where rule_id = $1",
      [pog.int(rule_id)],
    )
  execution_count_after |> should.equal(1)

  // Original execution is still 'applied'
  let assert Ok(execution) =
    fixtures.fetch_rule_execution(db, rule_id, "task", task_id)
  execution.outcome |> should.equal("applied")
}
