//// Integration tests for the rules engine.
////
//// Tests rule evaluation, idempotency, and task creation from templates.

import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleeunit/should
import pog
import scrumbringer_server
import scrumbringer_server/services/rules_engine.{
  Applied, Card, RuleResult, StateChangeEvent, Suppressed, Task,
}
import wisp
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

pub fn evaluate_rules_creates_tasks_from_templates_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create project
  create_project(handler, session, csrf, "Engineering")
  let project_id =
    single_int(db, "select id from projects where name = 'Engineering'", [])

  // Create task type
  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant")
  let bug_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_task_type(handler, session, csrf, project_id, "Review", "magnifier")
  let review_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Review'",
      [pog.int(project_id)],
    )

  // Create workflow
  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Auto QA")

  // Create task template for Review tasks
  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      review_type_id,
      "Review {{father}}",
    )

  // Create rule: when Bug task → completed, create Review
  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      Some(bug_type_id),
      "Bug Completed",
      "completed",
    )

  // Attach template to rule
  attach_template(handler, session, csrf, rule_id, template_id)

  // Get org_id and user_id for the event
  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  // Create a task to complete
  create_task(handler, session, csrf, project_id, bug_type_id, "Fix Login Bug")
  let task_id =
    single_int(db, "select id from tasks where title = 'Fix Login Bug'", [])

  // Simulate state change event
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("new"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(bug_type_id),
    )

  // Evaluate rules
  let result = rules_engine.evaluate_rules(db, event)

  // Should succeed with 1 task created
  result |> should.be_ok
  let assert Ok([RuleResult(rule_id: found_rule_id, outcome: Applied(1))]) =
    result
  found_rule_id |> should.equal(rule_id)

  // Verify task was created
  let review_count =
    single_int(
      db,
      "select count(*)::int from tasks where type_id = $1",
      [pog.int(review_type_id)],
    )
  review_count |> should.equal(1)
}

pub fn evaluate_rules_idempotency_suppresses_duplicate_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create project
  create_project(handler, session, csrf, "Idempotency Test")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'Idempotency Test'",
      [],
    )

  // Create task type
  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  // Create workflow and rule (no templates)
  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Idempotent Workflow")

  let _rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Completed",
      "completed",
    )

  // Get org_id and user_id
  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  // Create a task
  create_task(handler, session, csrf, project_id, type_id, "Test Task")
  let task_id =
    single_int(db, "select id from tasks where title = 'Test Task'", [])

  // Simulate state change event
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("new"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  // First evaluation - should apply
  let result1 = rules_engine.evaluate_rules(db, event)
  result1 |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(0))]) = result1

  // Second evaluation - should be suppressed (idempotent)
  let result2 = rules_engine.evaluate_rules(db, event)
  result2 |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Suppressed("idempotent"))]) =
    result2
}

pub fn evaluate_rules_skips_non_user_triggered_events_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create project
  create_project(handler, session, csrf, "Non-User Test")
  let project_id =
    single_int(db, "select id from projects where name = 'Non-User Test'", [])

  // Create task type and workflow with rule
  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Skip Non-User")
  let _rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Completed",
      "completed",
    )

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  // Event with user_triggered = False
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: 999,
      from_state: Some("new"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: False,
      task_type_id: Some(type_id),
    )

  // Should return empty list (no rules evaluated)
  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok
  let assert Ok([]) = result
}

pub fn evaluate_rules_card_resource_type_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create project
  create_project(handler, session, csrf, "Card Test")
  let project_id =
    single_int(db, "select id from projects where name = 'Card Test'", [])

  // Create workflow with card rule
  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Card Workflow")
  let _rule_id =
    create_rule_card(
      handler,
      session,
      csrf,
      workflow_id,
      "Card Closed",
      "closed",
    )

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  // Card state change event
  let event =
    StateChangeEvent(
      resource_type: Card,
      resource_id: 1,
      from_state: Some("open"),
      to_state: "closed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: None,
    )

  // Should find and apply the card rule
  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(0))]) = result
}

// =============================================================================
// Variable Substitution Tests
// =============================================================================

pub fn variable_father_task_resolves_to_link_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Setup
  create_project(handler, session, csrf, "VarTest")
  let project_id =
    single_int(db, "select id from projects where name = 'VarTest'", [])

  create_task_type(handler, session, csrf, project_id, "Feature", "star")
  let feature_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Feature'",
      [pog.int(project_id)],
    )

  create_task_type(handler, session, csrf, project_id, "Review", "eye")
  let review_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Review'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Father Var Test")

  // Template with {{father}} in title
  let template_id =
    create_template_with_desc(
      handler,
      session,
      csrf,
      project_id,
      review_type_id,
      "Review {{father}}",
      "Please review {{father}} carefully",
    )

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      Some(feature_type_id),
      "Feature Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  // Create trigger task
  create_task(handler, session, csrf, project_id, feature_type_id, "Add Login")
  let task_id =
    single_int(db, "select id from tasks where title = 'Add Login'", [])

  // Fire rules
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(feature_type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Verify created task has {{father}} resolved
  let created_title =
    single_string(
      db,
      "select title from tasks where type_id = $1 order by id desc limit 1",
      [pog.int(review_type_id)],
    )

  // Should contain [Task #N](/tasks/N) format
  created_title
  |> string.contains("[Task #" <> int_to_string(task_id))
  |> should.be_true

  created_title
  |> string.contains("/tasks/" <> int_to_string(task_id) <> ")")
  |> should.be_true

  // Also verify description
  let created_desc =
    single_string(
      db,
      "select description from tasks where type_id = $1 order by id desc limit 1",
      [pog.int(review_type_id)],
    )

  created_desc
  |> string.contains("[Task #" <> int_to_string(task_id))
  |> should.be_true
}

pub fn variable_father_card_resolves_to_link_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Setup
  create_project(handler, session, csrf, "CardVarTest")
  let project_id =
    single_int(db, "select id from projects where name = 'CardVarTest'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let task_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Card Father Test")

  // Template with {{father}} - should resolve to Card link
  let template_id =
    create_template_with_desc(
      handler,
      session,
      csrf,
      project_id,
      task_type_id,
      "Followup for {{father}}",
      "Card {{father}} was closed",
    )

  let rule_id =
    create_rule_card(handler, session, csrf, workflow_id, "Card Closed", "closed")

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let card_id = 42

  // Fire card event
  let event =
    StateChangeEvent(
      resource_type: Card,
      resource_id: card_id,
      from_state: Some("open"),
      to_state: "closed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: None,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Verify {{father}} resolved to Card link
  let created_title =
    single_string(
      db,
      "select title from tasks order by id desc limit 1",
      [],
    )

  created_title
  |> string.contains("[Card #" <> int_to_string(card_id))
  |> should.be_true

  created_title
  |> string.contains("/cards/" <> int_to_string(card_id) <> ")")
  |> should.be_true
}

pub fn variable_from_state_resolves_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "FromStateTest")
  let project_id =
    single_int(db, "select id from projects where name = 'FromStateTest'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "FromState Test")

  let template_id =
    create_template_with_desc(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "Changed from {{from_state}}",
      "Was {{from_state}}, now {{to_state}}",
    )

  let rule_id =
    create_rule(handler, session, csrf, workflow_id, None, "Any Done", "completed")

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_task(handler, session, csrf, project_id, type_id, "Original Task")
  let task_id =
    single_int(db, "select id from tasks where title = 'Original Task'", [])

  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Verify from_state resolved
  let created_title =
    single_string(
      db,
      "select title from tasks order by id desc limit 1",
      [],
    )
  created_title |> should.equal("Changed from claimed")

  // Verify description has both from_state and to_state
  let created_desc =
    single_string(
      db,
      "select description from tasks order by id desc limit 1",
      [],
    )
  created_desc |> should.equal("Was claimed, now completed")
}

pub fn variable_from_state_null_shows_created_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "NullFromStateTest")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'NullFromStateTest'",
      [],
    )

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Null FromState")

  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "Prev: {{from_state}}",
    )

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Available",
      "available",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  // Event with from_state = None (task just created)
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: 999,
      from_state: None,
      to_state: "available",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let created_title =
    single_string(db, "select title from tasks order by id desc limit 1", [])
  // from_state should show "(created)" when None
  created_title |> should.equal("Prev: (created)")
}

pub fn variable_project_resolves_to_name_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "My Awesome Project")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'My Awesome Project'",
      [],
    )

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Project Var Test")

  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "Task for {{project}}",
    )

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_task(handler, session, csrf, project_id, type_id, "Some Task")
  let task_id =
    single_int(db, "select id from tasks where title = 'Some Task'", [])

  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let created_title =
    single_string(db, "select title from tasks order by id desc limit 1", [])
  created_title |> should.equal("Task for My Awesome Project")
}

pub fn variable_user_resolves_to_email_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // User email is used as display_name (no separate display_name column)
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_project(handler, session, csrf, "UserVarTest")
  let project_id =
    single_int(db, "select id from projects where name = 'UserVarTest'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "User Var Test")

  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "Assigned by {{user}}",
    )

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])

  create_task(handler, session, csrf, project_id, type_id, "Test")
  let task_id = single_int(db, "select id from tasks where title = 'Test'", [])

  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let created_title =
    single_string(db, "select title from tasks order by id desc limit 1", [])
  // {{user}} resolves to user's email
  created_title |> should.equal("Assigned by admin@example.com")
}

pub fn variable_all_combined_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_project(handler, session, csrf, "AllVars")
  let project_id =
    single_int(db, "select id from projects where name = 'AllVars'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "All Vars Test")

  let template_id =
    create_template_with_desc(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "{{user}}: {{from_state}} -> {{to_state}}",
      "{{father}} in {{project}}",
    )

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])

  create_task(handler, session, csrf, project_id, type_id, "Origin")
  let task_id =
    single_int(db, "select id from tasks where title = 'Origin'", [])

  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let created_title =
    single_string(db, "select title from tasks order by id desc limit 1", [])
  // {{user}} resolves to email
  created_title |> should.equal("admin@example.com: claimed -> completed")

  let created_desc =
    single_string(
      db,
      "select description from tasks order by id desc limit 1",
      [],
    )
  // Description should have father link and project name
  created_desc |> string.contains("[Task #") |> should.be_true
  created_desc |> string.contains("in AllVars") |> should.be_true
}

// =============================================================================
// Positive Tests: Tasks SHOULD be created
// =============================================================================

pub fn multiple_templates_create_multiple_tasks_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "MultiTemplate")
  let project_id =
    single_int(db, "select id from projects where name = 'MultiTemplate'", [])

  create_task_type(handler, session, csrf, project_id, "Feature", "star")
  let feature_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Feature'",
      [pog.int(project_id)],
    )

  create_task_type(handler, session, csrf, project_id, "QA", "check")
  let qa_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(project_id)],
    )

  create_task_type(handler, session, csrf, project_id, "Docs", "book")
  let docs_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Docs'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Multi Template WF")

  // Create 3 templates
  let template1 =
    create_template(handler, session, csrf, project_id, qa_id, "QA Task")
  let template2 =
    create_template(handler, session, csrf, project_id, docs_id, "Docs Task")
  let template3 =
    create_template(handler, session, csrf, project_id, qa_id, "Another QA")

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      Some(feature_id),
      "Feature Done",
      "completed",
    )

  // Attach all 3 templates
  attach_template(handler, session, csrf, rule_id, template1)
  attach_template(handler, session, csrf, rule_id, template2)
  attach_template(handler, session, csrf, rule_id, template3)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_task(handler, session, csrf, project_id, feature_id, "New Feature")
  let task_id =
    single_int(db, "select id from tasks where title = 'New Feature'", [])

  let initial_count =
    single_int(db, "select count(*)::int from tasks", [])

  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(feature_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  let assert Ok([RuleResult(rule_id: _, outcome: Applied(3))]) = result

  // Verify 3 tasks were created
  let final_count =
    single_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count + 3)
}

pub fn rule_without_task_type_matches_all_types_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "NoTypeFilter")
  let project_id =
    single_int(db, "select id from projects where name = 'NoTypeFilter'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug")
  let bug_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_task_type(handler, session, csrf, project_id, "Feature", "star")
  let feature_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Feature'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "No Type WF")

  let template_id =
    create_template(handler, session, csrf, project_id, bug_id, "Followup")

  // Rule with NO task_type_id filter (None)
  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Completed",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  // Test with Bug type
  create_task(handler, session, csrf, project_id, bug_id, "Bug Task")
  let bug_task_id =
    single_int(db, "select id from tasks where title = 'Bug Task'", [])

  let event1 =
    StateChangeEvent(
      resource_type: Task,
      resource_id: bug_task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(bug_id),
    )

  let result1 = rules_engine.evaluate_rules(db, event1)
  result1 |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(1))]) = result1

  // Test with Feature type - should also match
  create_task(handler, session, csrf, project_id, feature_id, "Feature Task")
  let feature_task_id =
    single_int(db, "select id from tasks where title = 'Feature Task'", [])

  let event2 =
    StateChangeEvent(
      resource_type: Task,
      resource_id: feature_task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(feature_id),
    )

  let result2 = rules_engine.evaluate_rules(db, event2)
  result2 |> should.be_ok
  let assert Ok([RuleResult(rule_id: _, outcome: Applied(1))]) = result2
}

// =============================================================================
// Negative Tests: Tasks should NOT be created
// =============================================================================

pub fn inactive_workflow_does_not_fire_rules_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "InactiveWF")
  let project_id =
    single_int(db, "select id from projects where name = 'InactiveWF'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Inactive Workflow")

  // Deactivate workflow
  let assert Ok(_) =
    pog.query("update workflows set active = false where id = $1")
    |> pog.parameter(pog.int(workflow_id))
    |> pog.execute(db)

  let template_id =
    create_template(handler, session, csrf, project_id, type_id, "Should Not")

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_task(handler, session, csrf, project_id, type_id, "Trigger Task")
  let task_id =
    single_int(db, "select id from tasks where title = 'Trigger Task'", [])

  let initial_count = single_int(db, "select count(*)::int from tasks", [])

  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // No rules should match (workflow is inactive)
  let assert Ok([]) = result

  // No new tasks created
  let final_count = single_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count)
}

pub fn inactive_rule_does_not_fire_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "InactiveRule")
  let project_id =
    single_int(db, "select id from projects where name = 'InactiveRule'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Active WF")

  let template_id =
    create_template(handler, session, csrf, project_id, type_id, "Should Not")

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Inactive Rule",
      "completed",
    )

  // Deactivate rule
  let assert Ok(_) =
    pog.query("update rules set active = false where id = $1")
    |> pog.parameter(pog.int(rule_id))
    |> pog.execute(db)

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_task(handler, session, csrf, project_id, type_id, "Trigger")
  let task_id =
    single_int(db, "select id from tasks where title = 'Trigger'", [])

  let initial_count = single_int(db, "select count(*)::int from tasks", [])

  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // No rules should match
  let assert Ok([]) = result

  let final_count = single_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count)
}

pub fn wrong_task_type_does_not_match_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "WrongType")
  let project_id =
    single_int(db, "select id from projects where name = 'WrongType'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug")
  let bug_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_task_type(handler, session, csrf, project_id, "Feature", "star")
  let feature_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Feature'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Bug Only WF")

  let template_id =
    create_template(handler, session, csrf, project_id, bug_id, "Bug Followup")

  // Rule only fires for Bug type
  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      Some(bug_id),
      "Bug Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  // Create a Feature task (not Bug)
  create_task(handler, session, csrf, project_id, feature_id, "Feature Task")
  let task_id =
    single_int(db, "select id from tasks where title = 'Feature Task'", [])

  let initial_count = single_int(db, "select count(*)::int from tasks", [])

  // Event for Feature type task
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(feature_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Rule should not match (wrong type)
  let assert Ok([]) = result

  let final_count = single_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count)
}

pub fn wrong_to_state_does_not_match_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "WrongState")
  let project_id =
    single_int(db, "select id from projects where name = 'WrongState'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Completed Only WF")

  let template_id =
    create_template(handler, session, csrf, project_id, type_id, "Followup")

  // Rule only fires for "completed" state
  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "On Complete",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  create_task(handler, session, csrf, project_id, type_id, "A Task")
  let task_id =
    single_int(db, "select id from tasks where title = 'A Task'", [])

  let initial_count = single_int(db, "select count(*)::int from tasks", [])

  // Event for "claimed" state (not "completed")
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("available"),
      to_state: "claimed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Rule should not match (wrong to_state)
  let assert Ok([]) = result

  let final_count = single_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count)
}

pub fn project_scoped_workflow_does_not_apply_to_other_project_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create two projects
  create_project(handler, session, csrf, "ProjectA")
  let project_a_id =
    single_int(db, "select id from projects where name = 'ProjectA'", [])

  create_project(handler, session, csrf, "ProjectB")
  let project_b_id =
    single_int(db, "select id from projects where name = 'ProjectB'", [])

  // Create task type in both projects
  create_task_type(handler, session, csrf, project_a_id, "Task", "check")
  let type_a_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_a_id)],
    )

  create_task_type(handler, session, csrf, project_b_id, "Task", "check")
  let type_b_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_b_id)],
    )

  // Workflow scoped to Project A only
  let workflow_id =
    create_workflow(handler, session, csrf, project_a_id, "ProjectA WF")

  let template_id =
    create_template(handler, session, csrf, project_a_id, type_a_id, "A Task")

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Any Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  // Create task in Project B
  create_task(handler, session, csrf, project_b_id, type_b_id, "B Task")
  let task_id =
    single_int(db, "select id from tasks where title = 'B Task'", [])

  let initial_count = single_int(db, "select count(*)::int from tasks", [])

  // Event from Project B
  let event =
    StateChangeEvent(
      resource_type: Task,
      resource_id: task_id,
      from_state: Some("claimed"),
      to_state: "completed",
      project_id: project_b_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: Some(type_b_id),
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Project A workflow should not match event from Project B
  let assert Ok([]) = result

  let final_count = single_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count)
}

pub fn task_rule_does_not_fire_for_card_event_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "TaskOnlyRule")
  let project_id =
    single_int(db, "select id from projects where name = 'TaskOnlyRule'", [])

  create_task_type(handler, session, csrf, project_id, "Task", "check")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Task'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Task Rule WF")

  let template_id =
    create_template(handler, session, csrf, project_id, type_id, "Followup")

  // Rule for TASK resource_type
  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      None,
      "Task Done",
      "completed",
    )

  attach_template(handler, session, csrf, rule_id, template_id)

  let org_id = single_int(db, "select id from organizations limit 1", [])
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let initial_count = single_int(db, "select count(*)::int from tasks", [])

  // CARD event (not task)
  let event =
    StateChangeEvent(
      resource_type: Card,
      resource_id: 123,
      from_state: Some("open"),
      to_state: "completed",
      project_id: project_id,
      org_id: org_id,
      user_id: user_id,
      user_triggered: True,
      task_type_id: None,
    )

  let result = rules_engine.evaluate_rules(db, event)
  result |> should.be_ok

  // Task rule should not match card event
  let assert Ok([]) = result

  let final_count = single_int(db, "select count(*)::int from tasks", [])
  final_count |> should.equal(initial_count)
}

// =============================================================================
// Test Helpers
// =============================================================================

fn create_project(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  name: String,
) {
  let req =
    simulate.request(http.Post, "/api/v1/projects")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string(name))]))

  let res = handler(req)
  case res.status {
    200 -> Nil
    status ->
      panic as {
        "create_project failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res)
      }
  }
}

fn create_task_type(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  name: String,
  icon: String,
) {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("name", json.string(name)),
        #("icon", json.string(icon)),
      ]),
    )

  let res = handler(req)
  case res.status {
    200 -> Nil
    status ->
      panic as {
        "create_task_type failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res)
      }
  }
}

fn create_workflow(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  name: String,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("description", json.string("Test workflow")),
          #("active", json.bool(True)),
        ]),
      ),
    )

  // Fail with debug info if not 200
  case res.status {
    200 -> Nil
    status -> {
      let body = simulate.read_body(res)
      panic as {
        "create_workflow failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " project_id="
        <> int.to_string(project_id)
        <> " body="
        <> body
      }
    }
  }

  decode_workflow_id(simulate.read_body(res))
}

fn create_template(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  type_id: Int,
  name: String,
) -> Int {
  create_template_with_desc(
    handler,
    session,
    csrf,
    project_id,
    type_id,
    name,
    "Auto-created task",
  )
}

fn create_template_with_desc(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  type_id: Int,
  name: String,
  description: String,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("description", json.string(description)),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  case res.status {
    200 -> Nil
    status ->
      panic as {
        "create_template_with_desc failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res)
      }
  }
  decode_template_id(simulate.read_body(res))
}

fn create_rule(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  workflow_id: Int,
  task_type_id: option.Option(Int),
  name: String,
  to_state: String,
) -> Int {
  // Build JSON fields - omit task_type_id when None (don't send null)
  let base_fields = [
    #("name", json.string(name)),
    #("goal", json.string("Auto QA")),
    #("resource_type", json.string("task")),
    #("to_state", json.string(to_state)),
    #("active", json.bool(True)),
  ]

  let fields = case task_type_id {
    Some(id) -> [#("task_type_id", json.int(id)), ..base_fields]
    None -> base_fields
  }

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(json.object(fields)),
    )

  case res.status {
    200 -> Nil
    status ->
      panic as {
        "create_rule failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res)
      }
  }
  decode_rule_id(simulate.read_body(res))
}

fn create_rule_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  workflow_id: Int,
  name: String,
  to_state: String,
) -> Int {
  // Don't send task_type_id for card rules - omit field entirely
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("goal", json.string("Card automation")),
          #("resource_type", json.string("card")),
          #("to_state", json.string(to_state)),
          #("active", json.bool(True)),
        ]),
      ),
    )

  case res.status {
    200 -> Nil
    status ->
      panic as {
        "create_rule_card failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res)
      }
  }
  decode_rule_id(simulate.read_body(res))
}

fn attach_template(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  rule_id: Int,
  template_id: Int,
) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/rules/"
          <> int_to_string(rule_id)
          <> "/templates/"
          <> int_to_string(template_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(json.object([#("execution_order", json.int(1))])),
    )

  case res.status {
    200 -> Nil
    status ->
      panic as {
        "attach_template failed: status="
        <> int.to_string(status)
        <> " rule_id="
        <> int_to_string(rule_id)
        <> " template_id="
        <> int_to_string(template_id)
        <> " body="
        <> simulate.read_body(res)
      }
  }
}

fn create_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  type_id: Int,
  title: String,
) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("title", json.string(title)),
          #("description", json.string("Test task")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  case res.status {
    200 -> Nil
    status ->
      panic as {
        "create_task failed: status="
        <> int.to_string(status)
        <> " title="
        <> title
        <> " body="
        <> simulate.read_body(res)
      }
  }
}

fn decode_workflow_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let workflow_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use workflow <- decode.field("workflow", workflow_decoder)
    decode.success(workflow)
  }

  let response_decoder = {
    use workflow_id <- decode.field("data", data_decoder)
    decode.success(workflow_id)
  }

  let assert Ok(workflow_id) = decode.run(dynamic, response_decoder)
  workflow_id
}

fn decode_template_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let template_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    // API returns "template", not "task_template"
    use template <- decode.field("template", template_decoder)
    decode.success(template)
  }

  let response_decoder = {
    use template_id <- decode.field("data", data_decoder)
    decode.success(template_id)
  }

  let assert Ok(template_id) = decode.run(dynamic, response_decoder)
  template_id
}

fn decode_rule_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let rule_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use rule <- decode.field("rule", rule_decoder)
    decode.success(rule)
  }

  let response_decoder = {
    use rule_id <- decode.field("data", data_decoder)
    decode.success(rule_id)
  }

  let assert Ok(rule_id) = decode.run(dynamic, response_decoder)
  rule_id
}

fn login_as(
  handler: fn(wisp.Request) -> wisp.Response,
  email: String,
  password: String,
) -> wisp.Response {
  let req =
    simulate.request(http.Post, "/api/v1/auth/login")
    |> simulate.json_body(
      json.object([
        #("email", json.string(email)),
        #("password", json.string(password)),
      ]),
    )

  handler(req)
}

fn new_test_app() -> scrumbringer_server.App {
  let database_url = require_database_url()
  let assert Ok(app) = scrumbringer_server.new_app(secret, database_url)
  app
}

fn bootstrap_app() -> scrumbringer_server.App {
  let app = new_test_app()
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  reset_db(db)
  reset_workflow_tables(db)

  let res =
    handler(bootstrap_request("admin@example.com", "passwordpassword", "Acme"))

  case res.status {
    200 -> Nil
    status -> {
      let body = simulate.read_body(res)
      panic as {
        "bootstrap_app register failed: status="
        <> int.to_string(status)
        <> " body="
        <> body
      }
    }
  }

  app
}

fn bootstrap_request(email: String, password: String, org_name: String) {
  simulate.request(http.Post, "/api/v1/auth/register")
  |> simulate.json_body(
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
      #("org_name", json.string(org_name)),
    ]),
  )
}

fn set_cookie_headers(headers: List(#(String, String))) -> List(String) {
  headers
  |> list.filter_map(fn(h) {
    case h.0 {
      "set-cookie" -> Ok(h.1)
      _ -> Error(Nil)
    }
  })
}

fn find_cookie_value(headers: List(#(String, String)), name: String) -> String {
  let target = name <> "="

  let assert Ok(header) =
    set_cookie_headers(headers)
    |> list.find(fn(h) { string.starts_with(h, target) })

  let #(value, _) =
    header
    |> string.drop_start(string.length(target))
    |> string.split_once(";")
    |> result.unwrap(#("", ""))

  value
}

fn require_database_url() -> String {
  case getenv("DATABASE_URL", "") {
    "" -> {
      should.fail()
      ""
    }

    url -> url
  }
}

fn reset_db(db: pog.Connection) {
  let assert Ok(_) =
    pog.query(
      "TRUNCATE project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn reset_workflow_tables(db: pog.Connection) {
  let assert Ok(_) =
    pog.query(
      "TRUNCATE rule_templates, rule_executions, rules, workflows, task_templates, tasks, task_types RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn single_int(db: pog.Connection, sql: String, params: List(pog.Value)) -> Int {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn single_string(
  db: pog.Connection,
  sql: String,
  params: List(pog.Value),
) -> String {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn int_to_string(value: Int) -> String {
  value |> int_to_string_unsafe
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string_unsafe(value: Int) -> String

fn getenv(key: String, default: String) -> String {
  let key_charlist = charlist.from_string(key)
  let default_charlist = charlist.from_string(default)
  getenv_charlist(key_charlist, default_charlist)
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
