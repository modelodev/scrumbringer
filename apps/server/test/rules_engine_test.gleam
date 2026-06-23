//// Integration tests for the rules engine.
////
//// Tests rule evaluation, idempotency, and task creation from templates.
//// Uses shared fixtures for DRY and idiomatic Result handling.

import domain/automation
import domain/card as domain_card
import domain/task_status
import fixtures
import gleam/dynamic/decode
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server
import scrumbringer_server/use_case/rules_engine.{RuleResult}
import support/assertions as expect

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
      "Review {{origin}}",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Done",
      task_status.Done,
      template_id,
    )

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
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      bug_type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    result

  // Verify the Review task was created
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  count |> expect.equal(1)

  let assert Ok(traced_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where type_id = $1 and created_from_rule_id = $2",
      [pog.int(review_type_id), pog.int(rule_id)],
    )
  traced_count |> expect.equal(1)
}

pub fn evaluate_rules_idempotency_suppresses_duplicate_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Idempotent")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Feature", "star")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Idempotent WF")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Feature Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Build Feature")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
    )

  // First evaluation
  let result1 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    result1

  // Second evaluation - should be suppressed
  let result2 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(rule_id: rid, outcome: automation.DuplicateEvent)]) =
    result2
  rid |> expect.equal(rule_id)
}

pub fn evaluate_rules_skips_non_user_triggered_events_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "NonUser")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Auto WF")
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "System Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Event with user_triggered = False
  let event =
    fixtures.task_event_status_full(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
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
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Followup", "check")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Workflow")
  let assert Ok(_rule_id) =
    fixtures.create_rule_card(
      handler,
      session,
      workflow_id,
      "Card Closed",
      domain_card.Closed,
      template_id,
    )
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Test Card")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.card_event_state(
      card_id,
      project_id,
      org_id,
      user_id,
      Some(domain_card.Draft),
      domain_card.Closed,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    result
}

pub fn card_activated_rule_at_depth_only_matches_that_depth_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Card Activated Depth")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Followup", "check")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Depth WF")
  let assert Ok(_rule_id) =
    fixtures.create_rule_card_at_depth(
      handler,
      session,
      workflow_id,
      "Depth 2 Activated",
      domain_card.Active,
      2,
      template_id,
    )
  let assert Ok(root_card_id) =
    fixtures.create_card(handler, session, project_id, "Root Card")
  let assert Ok(child_card_id) =
    fixtures.create_child_card(
      handler,
      session,
      project_id,
      root_card_id,
      "Child Card",
    )

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let root_event =
    fixtures.card_event_state(
      root_card_id,
      project_id,
      org_id,
      user_id,
      Some(domain_card.Draft),
      domain_card.Active,
    )
  let assert Ok([]) = rules_engine.evaluate_rules(db, root_event)

  let child_event =
    fixtures.card_event_state(
      child_card_id,
      project_id,
      org_id,
      user_id,
      Some(domain_card.Draft),
      domain_card.Active,
    )
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    rules_engine.evaluate_rules(db, child_event)
}

pub fn card_closed_rule_at_depth_only_matches_that_depth_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Card Closed Depth")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Followup", "check")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Closed WF")
  let assert Ok(_rule_id) =
    fixtures.create_rule_card_at_depth(
      handler,
      session,
      workflow_id,
      "Depth 2 Closed",
      domain_card.Closed,
      2,
      template_id,
    )
  let assert Ok(root_card_id) =
    fixtures.create_card(handler, session, project_id, "Root Card")
  let assert Ok(child_card_id) =
    fixtures.create_child_card(
      handler,
      session,
      project_id,
      root_card_id,
      "Child Card",
    )

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let root_event =
    fixtures.card_event_state(
      root_card_id,
      project_id,
      org_id,
      user_id,
      Some(domain_card.Draft),
      domain_card.Closed,
    )
  let assert Ok([]) = rules_engine.evaluate_rules(db, root_event)

  let child_event =
    fixtures.card_event_state(
      child_card_id,
      project_id,
      org_id,
      user_id,
      Some(domain_card.Draft),
      domain_card.Closed,
    )
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    rules_engine.evaluate_rules(db, child_event)
}

// =============================================================================
// Variable Substitution Tests
// =============================================================================

pub fn variable_origin_task_resolves_to_link_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "OriginTask")
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
    fixtures.create_workflow(handler, session, project_id, "Origin Task Test")
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      review_type_id,
      "Review {{origin}}",
      "Desc for {{origin}}",
    )
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, bug_type_id, "Login Bug")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      bug_type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok

  // Verify the created task title contains the origin link
  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where type_id = $1 order by id desc limit 1",
      [pog.int(review_type_id)],
    )

  created_title
  |> string.contains("[Task #" <> int.to_string(task_id))
  |> expect.is_true

  created_title
  |> string.contains("/tasks/" <> int.to_string(task_id) <> ")")
  |> expect.is_true

  // Verify description also has the link
  let assert Ok(created_desc) =
    fixtures.query_string(
      db,
      "select description from tasks where type_id = $1 order by id desc limit 1",
      [pog.int(review_type_id)],
    )

  created_desc
  |> string.contains("[Task #" <> int.to_string(task_id))
  |> expect.is_true
}

pub fn variable_origin_card_resolves_to_link_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "CardVarTest")
  let assert Ok(task_type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Card Origin Test")
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      task_type_id,
      "Followup for {{card_title}} L{{card_level}}",
      "Card {{origin}} was closed: {{card_title}}",
    )
  let assert Ok(_rule_id) =
    fixtures.create_rule_card(
      handler,
      session,
      workflow_id,
      "Card Closed",
      domain_card.Closed,
      template_id,
    )
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card to Close")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.card_event_state(
      card_id,
      project_id,
      org_id,
      user_id,
      Some(domain_card.Draft),
      domain_card.Closed,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks order by id desc limit 1",
      [],
    )

  created_title |> expect.equal("Followup for Card to Close L1")

  let assert Ok(created_desc) =
    fixtures.query_string(
      db,
      "select description from tasks order by id desc limit 1",
      [],
    )

  created_desc
  |> string.contains("[Card #" <> int.to_string(card_id))
  |> expect.is_true
  created_desc |> string.contains("Card to Close") |> expect.is_true
}

pub fn variable_trigger_resolves_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "TriggerVariable")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Trigger Var Test")
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      type_id,
      "Trigger: {{trigger}}",
      "Changed to {{trigger}}",
    )
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Original Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'Trigger: completed'",
      [],
    )

  created_title |> expect.equal("Trigger: completed")
}

pub fn variable_trigger_on_created_task_uses_available_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "CreatedTrigger")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Created Trigger Test",
    )
  let assert Ok(template_id) =
    fixtures.create_template_with_desc(
      handler,
      session,
      project_id,
      type_id,
      "Trigger: {{trigger}}",
      "Was {{trigger}}",
    )
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "On Create",
      task_status.Available,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "New Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Task creation event (None -> available)
  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      None,
      task_status.Available,
      type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'Trigger: available'",
      [],
    )

  created_title |> expect.equal("Trigger: available")

  let assert Ok(created_desc) =
    fixtures.query_string(
      db,
      "select description from tasks where title = 'Trigger: available'",
      [],
    )

  created_desc |> expect.equal("Was available")
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
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Trigger Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'Task for My Project Name'",
      [],
    )

  created_title |> expect.equal("Task for My Project Name")
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
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "User Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok

  let assert Ok(created_title) =
    fixtures.query_string(
      db,
      "select title from tasks where title = 'Done by admin@example.com'",
      [],
    )

  // {{user}} resolves to email
  created_title |> expect.equal("Done by admin@example.com")
}

// Justification: large function kept intact to preserve cohesive logic.
/// Tests task trigger variables in one template.
pub fn task_trigger_variables_combined_test() {
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
      "{{task_type}} followup for {{task_title}}",
      "{{user}}: {{trigger}} in {{project}} from {{origin}}",
    )
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(bug_type_id),
      "Bug Done",
      task_status.Done,
      template_id,
    )

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
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      bug_type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    result

  // Verify the Review task was created (query by type_id to avoid flakiness)
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  count |> expect.equal(1)

  // Verify title has {{task_type}}, {{task_title}} (query by type_id)
  let assert Ok(created_title) =
    fixtures.query_string(db, "select title from tasks where type_id = $1", [
      pog.int(review_type_id),
    ])

  created_title |> expect.equal("Bug followup for Fix Combined Bug")

  // Verify description has common variables (query by type_id)
  let assert Ok(created_desc) =
    fixtures.query_string(
      db,
      "select description from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  created_desc |> string.contains("admin@example.com") |> expect.is_true
  created_desc |> string.contains("CombinedVars") |> expect.is_true
  created_desc
  |> string.contains("[Task #" <> int.to_string(task_id))
  |> expect.is_true
  created_desc
  |> string.contains(task_status.task_status_to_string(task_status.Done))
  |> expect.is_true
}

// =============================================================================
// Positive Tests
// =============================================================================

pub fn selecting_template_replaces_previous_rule_template_test() {
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

  // Create 3 templates and select each one in turn.
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
      task_status.Done,
      template1_id,
    )

  let assert Ok(Nil) =
    fixtures.select_rule_template(handler, session, rule_id, template2_id)
  let assert Ok(Nil) =
    fixtures.select_rule_template(handler, session, rule_id, template3_id)

  let assert Ok(selected_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from rule_templates where rule_id = $1",
      [pog.int(rule_id)],
    )
  selected_count |> expect.equal(1)

  let assert Ok(selected_template_id) =
    fixtures.query_int(
      db,
      "select template_id from rule_templates where rule_id = $1",
      [pog.int(rule_id)],
    )
  selected_template_id |> expect.equal(template3_id)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, bug_type_id, "Bug Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      bug_type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    result

  // Verify one Review task was created from the selected template.
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  count |> expect.equal(1)

  let assert Ok(created_title) =
    fixtures.query_string(db, "select title from tasks where type_id = $1", [
      pog.int(review_type_id),
    ])
  created_title |> expect.equal("Review 3")
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
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      bug_type_id,
      "Followup",
    )
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
      task_status.Done,
      template_id,
    )

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Create and trigger Bug task
  let assert Ok(bug_task_id) =
    fixtures.create_task(handler, session, project_id, bug_type_id, "Bug Task")

  let bug_event =
    fixtures.task_event_status(
      bug_task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      bug_type_id,
    )

  let bug_result = rules_engine.evaluate_rules(db, bug_event)
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    bug_result

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
    fixtures.task_event_status(
      feature_task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      feature_type_id,
    )

  let feature_result = rules_engine.evaluate_rules(db, feature_event)
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    feature_result
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
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
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
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
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
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Inactive Rule",
      task_status.Done,
      template_id,
    )

  // Deactivate rule
  let assert Ok(Nil) = fixtures.set_rule_active(db, rule_id, False)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
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
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      bug_type_id,
      "Followup",
    )
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
      task_status.Done,
      template_id,
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
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      feature_type_id,
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
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
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
      task_status.Done,
      template_id,
    )

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // Event with 'claimed' state (not 'completed')
  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Available),
      task_status.Claimed(task_status.Taken),
      type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([]) = result
}

pub fn task_created_and_released_rules_do_not_collide_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "AvailableTriggers")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Available WF")

  let assert Ok(created_rule_id) =
    insert_available_rule(db, workflow_id, "Created Rule", "task_created")
  let assert Ok(released_rule_id) =
    insert_available_rule(db, workflow_id, "Released Rule", "task_released")
  let assert Ok(Nil) = select_template(db, created_rule_id, template_id)
  let assert Ok(Nil) = select_template(db, released_rule_id, template_id)

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    fixtures.insert_task_db_simple(
      db,
      project_id,
      type_id,
      "Source Task",
      user_id,
      None,
    )

  let created_event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      None,
      task_status.Available,
      type_id,
    )
  let assert Ok([
    RuleResult(rule_id: created_matched, outcome: automation.Executed(_)),
  ]) = rules_engine.evaluate_rules(db, created_event)
  created_matched |> expect.equal(created_rule_id)

  let released_event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Available,
      type_id,
    )
  let assert Ok([
    RuleResult(rule_id: released_matched, outcome: automation.Executed(_)),
  ]) = rules_engine.evaluate_rules(db, released_event)
  released_matched |> expect.equal(released_rule_id)
}

pub fn project_scoped_workflow_does_not_apply_to_other_project_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  // Create two projects
  let assert Ok(project1_id) =
    fixtures.create_project(handler, session, "Project One")
  let assert Ok(project2_id) =
    fixtures.create_project(handler, session, "Project Two")

  let assert Ok(type1_id) =
    fixtures.create_task_type(handler, session, project1_id, "Task", "check")
  let assert Ok(type2_id) =
    fixtures.create_task_type(handler, session, project2_id, "Task", "check")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project1_id,
      type1_id,
      "Followup",
    )

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
      task_status.Done,
      template_id,
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
    fixtures.task_event_status(
      task_id,
      project2_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type2_id,
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
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Task Done",
      task_status.Done,
      template_id,
    )

  // Create a card
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card Not Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(initial_count) =
    fixtures.query_int(db, "select count(*)::int from tasks", [])

  // CARD event (not task)
  let event =
    fixtures.card_event_state(
      card_id,
      project_id,
      org_id,
      user_id,
      Some(domain_card.Draft),
      domain_card.Closed,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> expect.ok

  // Task rule should not match card event
  let assert Ok([]) = result

  let assert Ok(final_count) =
    fixtures.query_int(db, "select count(*)::int from tasks", [])
  final_count |> expect.equal(initial_count)
}

fn insert_available_rule(
  db: pog.Connection,
  workflow_id: Int,
  name: String,
  trigger_kind: String,
) -> Result(Int, String) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(id)
  }

  pog.query(
    "insert into rules (workflow_id, name, goal, resource_type, trigger_kind, task_type_id, to_state, active)
     values ($1, $2, 'Available trigger test', 'task', $3, null, 'available', true)
     returning id",
  )
  |> pog.parameter(pog.int(workflow_id))
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.text(trigger_kind))
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map_error(fn(error) { string.inspect(error) })
  |> result.try(fn(returned) {
    case returned.rows {
      [id] -> Ok(id)
      [] -> Error("rule insert returned no id")
      [_, _, ..] -> Error("rule insert returned multiple ids")
    }
  })
}

fn select_template(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
) -> Result(Nil, String) {
  pog.query(
    "insert into rule_templates (rule_id, template_id, execution_order)
     values ($1, $2, 1)",
  )
  |> pog.parameter(pog.int(rule_id))
  |> pog.parameter(pog.int(template_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(error) { string.inspect(error) })
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
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Persist Test WF")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Feature Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Feature")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(initial_count) =
    fixtures.query_int(db, "select count(*)::int from rule_executions", [])

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
    )

  let result = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(_, automation.Executed(_))]) = result

  // Verify execution was persisted
  let assert Ok(final_count) =
    fixtures.query_int(db, "select count(*)::int from rule_executions", [])
  final_count |> expect.equal(initial_count + 1)

  // Verify execution details using typed helper
  let assert Ok(execution) =
    fixtures.fetch_rule_execution(db, rule_id, "task", task_id)

  execution.outcome |> expect.equal("applied")
  execution.suppression_reason |> expect.equal("")
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
  let assert Ok(template_id) =
    fixtures.create_template(handler, session, project_id, type_id, "Followup")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      task_status.Done,
      template_id,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Bug Fix")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  let event =
    fixtures.task_event_status(
      task_id,
      project_id,
      org_id,
      user_id,
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
      type_id,
    )

  // First fire (applied)
  let result1 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(_, automation.Executed(_))]) = result1

  let assert Ok(execution_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from rule_executions where rule_id = $1",
      [pog.int(rule_id)],
    )
  execution_count |> expect.equal(1)
  let assert Ok(created_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where created_from_rule_id = $1",
      [pog.int(rule_id)],
    )
  created_count |> expect.equal(1)

  // Second fire (suppressed)
  let result2 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(_, automation.DuplicateEvent)]) = result2

  // Count remains 1 (unique constraint)
  let assert Ok(execution_count_after) =
    fixtures.query_int(
      db,
      "select count(*)::int from rule_executions where rule_id = $1",
      [pog.int(rule_id)],
    )
  execution_count_after |> expect.equal(1)
  let assert Ok(created_count_after) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where created_from_rule_id = $1",
      [pog.int(rule_id)],
    )
  created_count_after |> expect.equal(1)

  // Original execution is still 'applied'
  let assert Ok(execution) =
    fixtures.fetch_rule_execution(db, rule_id, "task", task_id)
  execution.outcome |> expect.equal("applied")
}
