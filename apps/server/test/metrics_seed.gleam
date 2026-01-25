//// Comprehensive test seed for metrics validation.
////
//// ## Purpose
////
//// Creates a realistic dataset with projects, users, workflows, rules,
//// tasks, and cards to validate:
//// - Project metrics screens (claimed, released, completed counts)
//// - Rule metrics screens (evaluated, applied, suppressed counts)
////
//// ## Usage
////
//// Run as a test: `gleam test -- --filter seed`
//// Or call `seed()` from other tests.
////
//// ## Data Created
////
//// - 2 projects: "Project Alpha" (main), "Project Beta" (secondary)
//// - 3 users: admin, developer, qa
//// - 3 task types per project: Bug, Feature, Task
//// - 4 task templates for automation
//// - 3 workflows with 6 rules total
//// - Multiple tasks and cards with rule executions

import fixtures
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import scrumbringer_server
import scrumbringer_server/services/rules_engine

// =============================================================================
// Public API
// =============================================================================

/// Run the full seed and return summary stats.
pub fn seed() -> Result(SeedResult, String) {
  io.println("\n========================================")
  io.println("  METRICS SEED - Creating test data")
  io.println("========================================\n")

  // Bootstrap
  use #(app, handler, session) <- result.try(fixtures.bootstrap())
  let scrumbringer_server.App(db: db, ..) = app
  io.println("[OK] Bootstrap complete")

  // Get org_id and admin user_id
  use org_id <- result.try(fixtures.get_org_id(db))
  use admin_user_id <- result.try(fixtures.get_user_id(db, "admin@example.com"))
  io.println(
    "[OK] Org ID: "
    <> int.to_string(org_id)
    <> ", Admin ID: "
    <> int.to_string(admin_user_id),
  )

  // Create additional users
  use dev_user_id <- result.try(fixtures.create_member_user(
    handler,
    db,
    "dev@example.com",
    "inv_dev_001",
  ))
  use qa_user_id <- result.try(fixtures.create_member_user(
    handler,
    db,
    "qa@example.com",
    "inv_qa_001",
  ))
  io.println(
    "[OK] Created users: dev="
    <> int.to_string(dev_user_id)
    <> ", qa="
    <> int.to_string(qa_user_id),
  )

  // =========================================================================
  // Project Alpha (main project)
  // =========================================================================
  io.println("\n--- Project Alpha ---")

  use alpha_id <- result.try(fixtures.create_project(
    handler,
    session,
    "Project Alpha",
  ))
  io.println("[OK] Created Project Alpha: " <> int.to_string(alpha_id))

  // Add members
  use _ <- result.try(fixtures.add_member(
    handler,
    session,
    alpha_id,
    dev_user_id,
    "member",
  ))
  use _ <- result.try(fixtures.add_member(
    handler,
    session,
    alpha_id,
    qa_user_id,
    "member",
  ))
  io.println("[OK] Added members to Alpha")

  // Task types for Alpha
  use alpha_bug_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    alpha_id,
    "Bug",
    "bug",
  ))
  use alpha_feature_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    alpha_id,
    "Feature",
    "feature",
  ))
  use alpha_task_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    alpha_id,
    "Task",
    "task",
  ))
  io.println(
    "[OK] Created task types: Bug="
    <> int.to_string(alpha_bug_type)
    <> ", Feature="
    <> int.to_string(alpha_feature_type)
    <> ", Task="
    <> int.to_string(alpha_task_type),
  )

  // Task templates for Alpha
  use alpha_review_tmpl <- result.try(fixtures.create_template_with_desc(
    handler,
    session,
    alpha_id,
    alpha_task_type,
    "Code Review",
    "Review the code changes",
  ))
  use alpha_qa_tmpl <- result.try(fixtures.create_template_with_desc(
    handler,
    session,
    alpha_id,
    alpha_task_type,
    "QA Verification",
    "Verify the fix works",
  ))
  use alpha_deploy_tmpl <- result.try(fixtures.create_template_with_desc(
    handler,
    session,
    alpha_id,
    alpha_task_type,
    "Deploy to Staging",
    "Deploy changes to staging environment",
  ))
  io.println(
    "[OK] Created templates: Review="
    <> int.to_string(alpha_review_tmpl)
    <> ", QA="
    <> int.to_string(alpha_qa_tmpl)
    <> ", Deploy="
    <> int.to_string(alpha_deploy_tmpl),
  )

  // =========================================================================
  // Workflows and Rules for Alpha
  // =========================================================================
  io.println("\n--- Workflows for Alpha ---")

  // Workflow 1: Bug Resolution (active)
  use wf_bug_id <- result.try(fixtures.create_workflow(
    handler,
    session,
    alpha_id,
    "Bug Resolution",
  ))
  io.println(
    "[OK] Created workflow: Bug Resolution (" <> int.to_string(wf_bug_id) <> ")",
  )

  // Rule: On Bug Resolved -> Create QA task
  use rule_bug_resolved <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_bug_id,
    Some(alpha_bug_type),
    "On Bug Resolved",
    "resolved",
  ))
  use _ <- result.try(fixtures.attach_template(
    handler,
    session,
    rule_bug_resolved,
    alpha_qa_tmpl,
  ))
  io.println(
    "  [+] Rule: On Bug Resolved ("
    <> int.to_string(rule_bug_resolved)
    <> ") -> QA template",
  )

  // Rule: On Bug Closed -> Create Deploy task
  use rule_bug_closed <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_bug_id,
    Some(alpha_bug_type),
    "On Bug Closed",
    "closed",
  ))
  use _ <- result.try(fixtures.attach_template(
    handler,
    session,
    rule_bug_closed,
    alpha_deploy_tmpl,
  ))
  io.println(
    "  [+] Rule: On Bug Closed ("
    <> int.to_string(rule_bug_closed)
    <> ") -> Deploy template",
  )

  // Workflow 2: Feature Development (active)
  use wf_feature_id <- result.try(fixtures.create_workflow(
    handler,
    session,
    alpha_id,
    "Feature Development",
  ))
  io.println(
    "[OK] Created workflow: Feature Development ("
    <> int.to_string(wf_feature_id)
    <> ")",
  )

  // Rule: On Feature Done -> Create Review task
  use rule_feature_done <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_feature_id,
    Some(alpha_feature_type),
    "On Feature Done",
    "done",
  ))
  use _ <- result.try(fixtures.attach_template(
    handler,
    session,
    rule_feature_done,
    alpha_review_tmpl,
  ))
  io.println(
    "  [+] Rule: On Feature Done ("
    <> int.to_string(rule_feature_done)
    <> ") -> Review template",
  )

  // Rule: On Feature QA Approved -> Create Deploy task
  use rule_feature_qa <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_feature_id,
    Some(alpha_feature_type),
    "On Feature QA Approved",
    "qa_approved",
  ))
  use _ <- result.try(fixtures.attach_template(
    handler,
    session,
    rule_feature_qa,
    alpha_deploy_tmpl,
  ))
  io.println(
    "  [+] Rule: On Feature QA Approved ("
    <> int.to_string(rule_feature_qa)
    <> ") -> Deploy template",
  )

  // Workflow 3: Card Automation (active)
  use wf_card_id <- result.try(fixtures.create_workflow(
    handler,
    session,
    alpha_id,
    "Card Automation",
  ))
  io.println(
    "[OK] Created workflow: Card Automation ("
    <> int.to_string(wf_card_id)
    <> ")",
  )

  // Rule: On Card Archived
  use rule_card_archived <- result.try(fixtures.create_rule_card(
    handler,
    session,
    wf_card_id,
    "On Card Archived",
    "archived",
  ))
  io.println(
    "  [+] Rule: On Card Archived (" <> int.to_string(rule_card_archived) <> ")",
  )

  // =========================================================================
  // Project Beta (secondary project)
  // =========================================================================
  io.println("\n--- Project Beta ---")

  use beta_id <- result.try(fixtures.create_project(
    handler,
    session,
    "Project Beta",
  ))
  io.println("[OK] Created Project Beta: " <> int.to_string(beta_id))

  // Task types for Beta
  use beta_bug_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    beta_id,
    "Bug",
    "bug",
  ))
  use _beta_feature_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    beta_id,
    "Feature",
    "feature",
  ))
  io.println("[OK] Created task types for Beta")

  // Simple workflow for Beta
  use wf_beta_id <- result.try(fixtures.create_workflow(
    handler,
    session,
    beta_id,
    "Simple Bug Flow",
  ))
  use _rule_beta_resolved <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_beta_id,
    Some(beta_bug_type),
    "On Beta Bug Resolved",
    "resolved",
  ))
  io.println("[OK] Created workflow and rule for Beta")

  // =========================================================================
  // Create Tasks and Trigger Rules
  // =========================================================================
  io.println("\n--- Creating Tasks and Triggering Rules ---")

  // Create bugs in Alpha
  let bug_titles = [
    "Login button not working",
    "Dashboard slow loading",
    "Profile picture upload fails",
    "Session timeout too short",
    "Email notifications delayed",
  ]

  use bug_ids <- result.try(
    list.try_map(bug_titles, fn(title) {
      fixtures.create_task(handler, session, alpha_id, alpha_bug_type, title)
    }),
  )
  io.println(
    "[OK] Created " <> int.to_string(list.length(bug_ids)) <> " bugs in Alpha",
  )

  // Create features in Alpha
  let feature_titles = [
    "Dark mode support",
    "Export to PDF",
    "Notification preferences",
  ]

  use feature_ids <- result.try(
    list.try_map(feature_titles, fn(title) {
      fixtures.create_task(
        handler,
        session,
        alpha_id,
        alpha_feature_type,
        title,
      )
    }),
  )
  io.println(
    "[OK] Created "
    <> int.to_string(list.length(feature_ids))
    <> " features in Alpha",
  )

  // Create cards in Alpha
  let card_titles = [
    "Sprint Planning Notes",
    "Architecture Decision Record",
    "Retrospective Summary",
    "Release Checklist",
  ]

  use card_ids <- result.try(
    list.try_map(card_titles, fn(title) {
      fixtures.create_card(handler, session, alpha_id, title)
    }),
  )
  io.println(
    "[OK] Created " <> int.to_string(list.length(card_ids)) <> " cards in Alpha",
  )

  // Create bugs in Beta
  use beta_bug_ids <- result.try(
    list.try_map(["Beta Bug 1", "Beta Bug 2"], fn(title) {
      fixtures.create_task(handler, session, beta_id, beta_bug_type, title)
    }),
  )
  io.println(
    "[OK] Created "
    <> int.to_string(list.length(beta_bug_ids))
    <> " bugs in Beta",
  )

  // =========================================================================
  // Trigger Rule Executions
  // =========================================================================
  io.println("\n--- Triggering Rule Executions ---")

  // Resolve some bugs (triggers "On Bug Resolved" rule)
  let resolved_bugs = list.take(bug_ids, 3)
  use _ <- result.try(
    list.try_map(resolved_bugs, fn(bug_id) {
      let event =
        fixtures.task_event(
          bug_id,
          alpha_id,
          org_id,
          admin_user_id,
          Some("in_progress"),
          "resolved",
          Some(alpha_bug_type),
        )
      rules_engine.evaluate_rules(db, event)
      |> result.map_error(fn(e) {
        "Rule evaluation failed: " <> string.inspect(e)
      })
    }),
  )
  io.println(
    "[OK] Triggered 'On Bug Resolved' for "
    <> int.to_string(list.length(resolved_bugs))
    <> " bugs",
  )

  // Close some bugs (triggers "On Bug Closed" rule)
  let closed_bugs = list.take(bug_ids, 2)
  use _ <- result.try(
    list.try_map(closed_bugs, fn(bug_id) {
      let event =
        fixtures.task_event(
          bug_id,
          alpha_id,
          org_id,
          admin_user_id,
          Some("resolved"),
          "closed",
          Some(alpha_bug_type),
        )
      rules_engine.evaluate_rules(db, event)
      |> result.map_error(fn(e) {
        "Rule evaluation failed: " <> string.inspect(e)
      })
    }),
  )
  io.println(
    "[OK] Triggered 'On Bug Closed' for "
    <> int.to_string(list.length(closed_bugs))
    <> " bugs",
  )

  // Complete some features (triggers "On Feature Done" rule)
  let done_features = list.take(feature_ids, 2)
  use _ <- result.try(
    list.try_map(done_features, fn(feature_id) {
      let event =
        fixtures.task_event(
          feature_id,
          alpha_id,
          org_id,
          dev_user_id,
          Some("in_progress"),
          "done",
          Some(alpha_feature_type),
        )
      rules_engine.evaluate_rules(db, event)
      |> result.map_error(fn(e) {
        "Rule evaluation failed: " <> string.inspect(e)
      })
    }),
  )
  io.println(
    "[OK] Triggered 'On Feature Done' for "
    <> int.to_string(list.length(done_features))
    <> " features",
  )

  // QA approve one feature (triggers "On Feature QA Approved" rule)
  let assert [first_feature, ..] = feature_ids
  let event_qa =
    fixtures.task_event(
      first_feature,
      alpha_id,
      org_id,
      qa_user_id,
      Some("done"),
      "qa_approved",
      Some(alpha_feature_type),
    )
  use _ <- result.try(
    rules_engine.evaluate_rules(db, event_qa)
    |> result.map_error(fn(e) {
      "Rule evaluation failed: " <> string.inspect(e)
    }),
  )
  io.println("[OK] Triggered 'On Feature QA Approved' for 1 feature")

  // Archive some cards (triggers "On Card Archived" rule)
  let archived_cards = list.take(card_ids, 2)
  use _ <- result.try(
    list.try_map(archived_cards, fn(card_id) {
      let event =
        fixtures.card_event(
          card_id,
          alpha_id,
          org_id,
          admin_user_id,
          Some("active"),
          "archived",
        )
      rules_engine.evaluate_rules(db, event)
      |> result.map_error(fn(e) {
        "Rule evaluation failed: " <> string.inspect(e)
      })
    }),
  )
  io.println(
    "[OK] Triggered 'On Card Archived' for "
    <> int.to_string(list.length(archived_cards))
    <> " cards",
  )

  // =========================================================================
  // Trigger Suppressed Executions (for metrics variety)
  // =========================================================================
  io.println("\n--- Triggering Suppressed Executions ---")

  // Idempotent: Try to resolve the same bug again (should suppress)
  let assert [first_bug, ..] = bug_ids
  let event_idem =
    fixtures.task_event(
      first_bug,
      alpha_id,
      org_id,
      admin_user_id,
      Some("claimed"),
      "resolved",
      Some(alpha_bug_type),
    )
  use _ <- result.try(
    rules_engine.evaluate_rules(db, event_idem)
    |> result.map_error(fn(e) {
      "Rule evaluation failed: " <> string.inspect(e)
    }),
  )
  io.println("[OK] Triggered idempotent suppression")

  // Not user triggered: system event (should skip entirely)
  let assert [second_bug, ..] = list.drop(bug_ids, 1)
  let event_system =
    fixtures.task_event_full(
      second_bug,
      alpha_id,
      org_id,
      admin_user_id,
      Some("draft"),
      "resolved",
      Some(alpha_bug_type),
      False,
      // user_triggered = False
      None,
      // card_id
    )
  use _ <- result.try(
    rules_engine.evaluate_rules(db, event_system)
    |> result.map_error(fn(e) {
      "Rule evaluation failed: " <> string.inspect(e)
    }),
  )
  io.println("[OK] Triggered system event (not user triggered)")

  // Resolve Beta bugs
  use _ <- result.try(
    list.try_map(beta_bug_ids, fn(bug_id) {
      let event =
        fixtures.task_event(
          bug_id,
          beta_id,
          org_id,
          admin_user_id,
          Some("in_progress"),
          "resolved",
          Some(beta_bug_type),
        )
      rules_engine.evaluate_rules(db, event)
      |> result.map_error(fn(e) {
        "Rule evaluation failed: " <> string.inspect(e)
      })
    }),
  )
  io.println(
    "[OK] Triggered 'On Beta Bug Resolved' for "
    <> int.to_string(list.length(beta_bug_ids))
    <> " bugs",
  )

  // =========================================================================
  // Summary
  // =========================================================================
  io.println("\n========================================")
  io.println("  SEED COMPLETE")
  io.println("========================================")
  io.println("")
  io.println("Projects created: 2 (Alpha, Beta)")
  io.println("Users created: 3 (admin, dev, qa)")
  io.println("Workflows created: 4")
  io.println("Rules created: 6")
  io.println(
    "Tasks created: "
    <> int.to_string(
      list.length(bug_ids)
      + list.length(feature_ids)
      + list.length(beta_bug_ids),
    ),
  )
  io.println("Cards created: " <> int.to_string(list.length(card_ids)))
  io.println("")
  io.println("Rule executions triggered:")
  io.println(
    "  - On Bug Resolved (Alpha): "
    <> int.to_string(list.length(resolved_bugs))
    <> " applied",
  )
  io.println(
    "  - On Bug Closed (Alpha): "
    <> int.to_string(list.length(closed_bugs))
    <> " applied",
  )
  io.println(
    "  - On Feature Done (Alpha): "
    <> int.to_string(list.length(done_features))
    <> " applied",
  )
  io.println("  - On Feature QA Approved (Alpha): 1 applied")
  io.println(
    "  - On Card Archived (Alpha): "
    <> int.to_string(list.length(archived_cards))
    <> " applied",
  )
  io.println(
    "  - On Beta Bug Resolved: "
    <> int.to_string(list.length(beta_bug_ids))
    <> " applied",
  )
  io.println("  - Idempotent suppression: 1")
  io.println("")
  io.println("Login credentials:")
  io.println("  admin@example.com / passwordpassword")
  io.println("  dev@example.com / passwordpassword")
  io.println("  qa@example.com / passwordpassword")
  io.println("")

  Ok(SeedResult(
    projects: 2,
    users: 3,
    workflows: 4,
    rules: 6,
    tasks: list.length(bug_ids)
      + list.length(feature_ids)
      + list.length(beta_bug_ids),
    cards: list.length(card_ids),
    rule_executions: list.length(resolved_bugs)
      + list.length(closed_bugs)
      + list.length(done_features)
      + 1
      + list.length(archived_cards)
      + list.length(beta_bug_ids)
      + 1,
  ))
}

// =============================================================================
// Types
// =============================================================================

/// Summary of seed data created.
pub type SeedResult {
  SeedResult(
    projects: Int,
    users: Int,
    workflows: Int,
    rules: Int,
    tasks: Int,
    cards: Int,
    rule_executions: Int,
  )
}

// =============================================================================
// Test Entry Point
// =============================================================================

/// Test that runs the seed.
/// Use: DATABASE_URL=... gleam test -- --filter run_metrics_seed
pub fn run_metrics_seed_test() {
  let result = seed()
  case result {
    Ok(stats) -> {
      io.println("\nSeed completed successfully!")
      io.println(
        "Stats: "
        <> int.to_string(stats.rule_executions)
        <> " rule executions created",
      )
    }
    Error(msg) -> {
      io.println("\nSeed FAILED: " <> msg)
      panic as msg
    }
  }
}
