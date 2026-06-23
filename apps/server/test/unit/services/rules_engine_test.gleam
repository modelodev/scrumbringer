//// Unit tests for rules engine evaluation.
////
//// Tests rule evaluation including matching, inactive rules, and idempotency.
//// Uses fixtures.gleam for test setup.

import domain/automation
import domain/task_status
import fixtures
import gleam/option.{None, Some}
import gleeunit
import scrumbringer_server
import scrumbringer_server/use_case/rules_engine.{RuleResult}
import support/assertions as expect

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC6: Rule evaluation applies matching rule test
// =============================================================================

pub fn evaluate_rule_applies_matching_rule_test() {
  // Given: Active workflow with rule that matches event criteria
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Rule Apply Test")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Apply Test WF")
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Bug Complete",
      task_status.Done,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Bug")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // When: Fire event that matches rule criteria
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

  // Then: Rule is applied
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    result
}

// =============================================================================
// AC7: Rule evaluation skips inactive rule test
// =============================================================================

pub fn evaluate_rule_skips_inactive_rule_test() {
  // Given: Workflow with inactive rule
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Inactive Rule Test")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Inactive Rule WF")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Inactive Rule",
      task_status.Done,
    )

  // Deactivate the rule
  let assert Ok(Nil) = fixtures.set_rule_active(db, rule_id, False)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // When: Fire event
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

  // Then: No rules fire (inactive rule is skipped)
  let assert Ok([]) = result
}

// =============================================================================
// AC8: Rule evaluation handles idempotent suppression test
// =============================================================================

pub fn evaluate_rule_handles_idempotent_suppression_test() {
  // Given: Workflow with rule, and the rule has already been executed for this origin
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Idempotent Test")
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
      task_status.Done,
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Feature")

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

  // First evaluation - should apply
  let result1 = rules_engine.evaluate_rules(db, event)
  let assert Ok([RuleResult(rule_id: _, outcome: automation.Executed(_))]) =
    result1

  // When: Same event fires again
  let result2 = rules_engine.evaluate_rules(db, event)

  // Then: Rule is suppressed as idempotent
  let assert Ok([RuleResult(rule_id: rid, outcome: automation.DuplicateEvent)]) =
    result2
  rid |> expect.equal(rule_id)
}

// =============================================================================
// Additional coverage: Inactive workflow test
// =============================================================================

pub fn evaluate_rule_skips_when_workflow_inactive_test() {
  // Given: Inactive workflow with rule
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Inactive WF Test")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Inactive Workflow")
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      None,
      "Any Done",
      task_status.Done,
    )

  // Deactivate workflow
  let assert Ok(Nil) = fixtures.set_workflow_active(db, workflow_id, False)

  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Test Task")

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")

  // When: Fire event
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

  // Then: No rules fire (workflow is inactive)
  let assert Ok([]) = result
}
