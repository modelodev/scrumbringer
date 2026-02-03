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
//// Uses seed_builder with a metrics-focused configuration that ensures
//// good coverage of edge cases and realistic data distribution.

import fixtures
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import scrumbringer_server
import scrumbringer_server/seed_builder
import scrumbringer_server/services/rules_engine

// =============================================================================
// Public API
// =============================================================================

/// Configuration optimized for metrics testing.
pub fn metrics_config() -> seed_builder.SeedConfig {
  seed_builder.SeedConfig(
    user_count: 4,
    inactive_user_count: 1,
    project_count: 2,
    empty_project_count: 0,
    tasks_per_project: 10,
    priority_distribution: [1, 2, 3, 3, 3, 4, 5],
    status_distribution: seed_builder.StatusDistribution(
      available: 25,
      claimed: 45,
      completed: 30,
    ),
    cards_per_project: 4,
    empty_card_count: 1,
    workflows_per_project: 3,
    inactive_workflow_count: 0,
    empty_workflow_count: 0,
    date_range_days: 14,
  )
}

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

  // Create additional users via API for proper authentication setup
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

  // Create projects via API
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
    "bug-ant",
  ))
  use alpha_feature_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    alpha_id,
    "Feature",
    "sparkles",
  ))
  use alpha_task_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    alpha_id,
    "Task",
    "clipboard-document-check",
  ))
  io.println("[OK] Created task types")

  // Task templates
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
    "Deploy changes to staging",
  ))
  io.println("[OK] Created templates")

  // Workflows and rules
  io.println("\n--- Workflows for Alpha ---")

  use wf_bug_id <- result.try(fixtures.create_workflow(
    handler,
    session,
    alpha_id,
    "Bug Resolution",
  ))
  io.println("[OK] Created Bug Resolution workflow")

  use rule_bug_resolved <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_bug_id,
    Some(alpha_bug_type),
    "On Bug Resolved",
    "completed",
  ))
  use _ <- result.try(fixtures.attach_template(
    handler,
    session,
    rule_bug_resolved,
    alpha_qa_tmpl,
  ))
  io.println("  [+] Rule: On Bug Resolved -> QA template")

  use rule_bug_closed <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_bug_id,
    Some(alpha_bug_type),
    "On Bug Closed",
    "completed",
  ))
  use _ <- result.try(fixtures.attach_template(
    handler,
    session,
    rule_bug_closed,
    alpha_deploy_tmpl,
  ))
  io.println("  [+] Rule: On Bug Closed -> Deploy template")

  use wf_feature_id <- result.try(fixtures.create_workflow(
    handler,
    session,
    alpha_id,
    "Feature Development",
  ))
  io.println("[OK] Created Feature Development workflow")

  use rule_feature_done <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_feature_id,
    Some(alpha_feature_type),
    "On Feature Done",
    "completed",
  ))
  use _ <- result.try(fixtures.attach_template(
    handler,
    session,
    rule_feature_done,
    alpha_review_tmpl,
  ))
  io.println("  [+] Rule: On Feature Done -> Review template")

  use wf_card_id <- result.try(fixtures.create_workflow(
    handler,
    session,
    alpha_id,
    "Card Automation",
  ))
  use _rule_card <- result.try(fixtures.create_rule_card(
    handler,
    session,
    wf_card_id,
    "On Card Archived",
    "cerrada",
  ))
  io.println("[OK] Created Card Automation workflow")

  // Project Beta
  io.println("\n--- Project Beta ---")
  use beta_id <- result.try(fixtures.create_project(
    handler,
    session,
    "Project Beta",
  ))
  io.println("[OK] Created Project Beta")

  use beta_bug_type <- result.try(fixtures.create_task_type(
    handler,
    session,
    beta_id,
    "Bug",
    "bug-ant",
  ))
  use _beta_feature <- result.try(fixtures.create_task_type(
    handler,
    session,
    beta_id,
    "Feature",
    "sparkles",
  ))

  use wf_beta <- result.try(fixtures.create_workflow(
    handler,
    session,
    beta_id,
    "Simple Bug Flow",
  ))
  use _rule_beta <- result.try(fixtures.create_rule(
    handler,
    session,
    wf_beta,
    Some(beta_bug_type),
    "On Beta Bug Resolved",
    "completed",
  ))
  io.println("[OK] Created workflow for Beta")

  // Create tasks
  io.println("\n--- Creating Tasks ---")

  let bug_titles = [
    "Login button not working", "Dashboard slow loading",
    "Profile picture upload fails", "Session timeout too short",
    "Email notifications delayed",
  ]
  use bug_ids <- result.try(
    list.try_map(bug_titles, fn(title) {
      fixtures.create_task(handler, session, alpha_id, alpha_bug_type, title)
    }),
  )
  io.println("[OK] Created " <> int.to_string(list.length(bug_ids)) <> " bugs")

  let feature_titles = [
    "Dark mode support", "Export to PDF", "Notification preferences",
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
    "[OK] Created " <> int.to_string(list.length(feature_ids)) <> " features",
  )

  let card_titles = [
    "Sprint Planning", "Architecture", "Retrospective", "Release",
  ]
  use card_ids <- result.try(
    list.try_map(card_titles, fn(title) {
      fixtures.create_card(handler, session, alpha_id, title)
    }),
  )
  io.println(
    "[OK] Created " <> int.to_string(list.length(card_ids)) <> " cards",
  )

  use beta_bug_ids <- result.try(
    list.try_map(["Beta Bug 1", "Beta Bug 2"], fn(title) {
      fixtures.create_task(handler, session, beta_id, beta_bug_type, title)
    }),
  )
  io.println(
    "[OK] Created " <> int.to_string(list.length(beta_bug_ids)) <> " Beta bugs",
  )

  // Trigger rule executions
  io.println("\n--- Triggering Rule Executions ---")

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
          "completed",
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

  let closed_bugs = list.take(bug_ids, 2)
  use _ <- result.try(
    list.try_map(closed_bugs, fn(bug_id) {
      let event =
        fixtures.task_event(
          bug_id,
          alpha_id,
          org_id,
          admin_user_id,
          Some("completed"),
          "completed",
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
          "completed",
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
          "cerrada",
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

  // Beta bugs
  use _ <- result.try(
    list.try_map(beta_bug_ids, fn(bug_id) {
      let event =
        fixtures.task_event(
          bug_id,
          beta_id,
          org_id,
          admin_user_id,
          Some("in_progress"),
          "completed",
          Some(beta_bug_type),
        )
      rules_engine.evaluate_rules(db, event)
      |> result.map_error(fn(e) {
        "Rule evaluation failed: " <> string.inspect(e)
      })
    }),
  )
  io.println("[OK] Triggered Beta bug rules")

  // Idempotent test
  io.println("\n--- Testing Suppression ---")
  let assert [first_bug, ..] = bug_ids
  let event_idem =
    fixtures.task_event(
      first_bug,
      alpha_id,
      org_id,
      admin_user_id,
      Some("claimed"),
      "completed",
      Some(alpha_bug_type),
    )
  use _ <- result.try(
    rules_engine.evaluate_rules(db, event_idem)
    |> result.map_error(fn(e) {
      "Rule evaluation failed: " <> string.inspect(e)
    }),
  )
  io.println("[OK] Triggered idempotent suppression")

  // Summary
  io.println("\n========================================")
  io.println("  SEED COMPLETE")
  io.println("========================================")
  io.println("")
  io.println("Projects: 2 (Alpha, Beta)")
  io.println("Users: 3 (admin, dev, qa)")
  io.println("Workflows: 4")
  io.println("Rules: 5")
  io.println(
    "Tasks: "
    <> int.to_string(
      list.length(bug_ids)
      + list.length(feature_ids)
      + list.length(beta_bug_ids),
    ),
  )
  io.println("Cards: " <> int.to_string(list.length(card_ids)))
  io.println("")
  io.println("Login credentials:")
  io.println("  admin@example.com / passwordpassword")
  io.println("  dev@example.com / passwordpassword")
  io.println("  qa@example.com / passwordpassword")
  io.println("")

  let rule_execs =
    list.length(resolved_bugs)
    + list.length(closed_bugs)
    + list.length(done_features)
    + list.length(archived_cards)
    + list.length(beta_bug_ids)
    + 1

  Ok(SeedResult(
    projects: 2,
    users: 3,
    workflows: 4,
    rules: 5,
    tasks: list.length(bug_ids)
      + list.length(feature_ids)
      + list.length(beta_bug_ids),
    cards: list.length(card_ids),
    rule_executions: rule_execs,
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
