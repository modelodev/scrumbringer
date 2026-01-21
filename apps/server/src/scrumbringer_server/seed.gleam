//// Standalone seed module for populating test data.
////
//// ## Usage
////
//// ```bash
//// cd apps/server
//// DATABASE_URL=... gleam run -m scrumbringer_server/seed
//// ```

import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server
import scrumbringer_server/services/rules_engine.{
  Card, StateChangeEvent, Task,
}

// =============================================================================
// Main Entry Point
// =============================================================================

pub fn main() {
  io.println("\n========================================")
  io.println("  METRICS SEED - Standalone")
  io.println("========================================\n")

  case run_seed() {
    Ok(stats) -> {
      io.println("\n========================================")
      io.println("  SEED COMPLETE")
      io.println("========================================")
      io.println("")
      io.println("Projects: " <> int.to_string(stats.projects))
      io.println("Users: " <> int.to_string(stats.users))
      io.println("Task types: " <> int.to_string(stats.task_types))
      io.println("Workflows: " <> int.to_string(stats.workflows))
      io.println("Rules: " <> int.to_string(stats.rules))
      io.println("Tasks: " <> int.to_string(stats.tasks))
      io.println("Cards: " <> int.to_string(stats.cards))
      io.println("Rule executions: " <> int.to_string(stats.rule_executions))
      io.println("Task events: " <> int.to_string(stats.task_events))
      io.println("")
      io.println("=== Test Users (password: passwordpassword) ===")
      io.println("  admin@example.com    - Org Admin (manager on all projects)")
      io.println("  pm@example.com       - Org Member, Project Manager on Alpha")
      io.println("  member@example.com   - Org Member, Project Member on Alpha")
      io.println("  beta@example.com     - Org Member, Project Manager on Beta only")
      io.println("")
    }
    Error(msg) -> {
      io.println("\n[ERROR] " <> msg)
    }
  }
}

// =============================================================================
// Types
// =============================================================================

pub type SeedStats {
  SeedStats(
    projects: Int,
    users: Int,
    task_types: Int,
    workflows: Int,
    rules: Int,
    tasks: Int,
    cards: Int,
    rule_executions: Int,
    task_events: Int,
  )
}

// =============================================================================
// Seed Logic
// =============================================================================

fn run_seed() -> Result(SeedStats, String) {
  use db_url <- result.try(database_url())
  io.println("[OK] DATABASE_URL found")

  // Create app to get db connection
  use app <- result.try(
    scrumbringer_server.new_app("seed-secret", db_url)
    |> result.map_error(fn(_) { "Failed to connect to database" })
  )
  let scrumbringer_server.App(db: db, ..) = app
  io.println("[OK] Connected to database")

  // Get org_id and admin user_id
  use org_id <- result.try(query_int(db, "SELECT id FROM organizations LIMIT 1"))
  use admin_id <- result.try(query_int(db, "SELECT id FROM users WHERE email = 'admin@example.com'"))
  io.println("[OK] Org ID: " <> int.to_string(org_id) <> ", Admin ID: " <> int.to_string(admin_id))

  // Reset workflow tables (keep users, org, default project)
  use _ <- result.try(reset_workflow_tables(db))
  io.println("[OK] Reset workflow tables")

  // =========================================================================
  // Create Test Users (varied roles for UI validation)
  // =========================================================================
  io.println("\n--- Creating Test Users ---")

  // pm@example.com - Org Member who will be Project Manager on Alpha
  use pm_id <- result.try(upsert_user(db, org_id, "pm@example.com", "member"))
  io.println("[OK] pm@example.com ID: " <> int.to_string(pm_id))

  // member@example.com - Org Member who will be Project Member on Alpha
  use member_id <- result.try(upsert_user(db, org_id, "member@example.com", "member"))
  io.println("[OK] member@example.com ID: " <> int.to_string(member_id))

  // beta@example.com - Org Member who will be Project Manager on Beta only
  use beta_user_id <- result.try(upsert_user(db, org_id, "beta@example.com", "member"))
  io.println("[OK] beta@example.com ID: " <> int.to_string(beta_user_id))

  // =========================================================================
  // Project Alpha (multi-role testing)
  // =========================================================================
  io.println("\n--- Creating Project Alpha ---")

  use alpha_id <- result.try(insert_project(db, org_id, "Project Alpha"))
  // admin@example.com as manager (Org Admin)
  use _ <- result.try(insert_member(db, alpha_id, admin_id, "manager"))
  // pm@example.com as manager (Org Member who is Project Manager)
  use _ <- result.try(insert_member(db, alpha_id, pm_id, "manager"))
  // member@example.com as member (Org Member who is Project Member)
  use _ <- result.try(insert_member(db, alpha_id, member_id, "member"))
  io.println("[OK] Project Alpha ID: " <> int.to_string(alpha_id))
  io.println("[OK] Alpha members: admin (manager), pm (manager), member (member)")

  use alpha_bug_type <- result.try(insert_task_type(db, alpha_id, "Bug", "bug-ant"))
  use alpha_feature_type <- result.try(insert_task_type(db, alpha_id, "Feature", "sparkles"))
  use alpha_task_type <- result.try(insert_task_type(db, alpha_id, "Task", "clipboard-document-check"))
  io.println("[OK] Task types created")

  use alpha_review_tmpl <- result.try(
    insert_template(db, org_id, alpha_id, alpha_task_type, "Code Review", admin_id)
  )
  use alpha_qa_tmpl <- result.try(
    insert_template(db, org_id, alpha_id, alpha_task_type, "QA Verification", admin_id)
  )
  use alpha_deploy_tmpl <- result.try(
    insert_template(db, org_id, alpha_id, alpha_task_type, "Deploy to Staging", admin_id)
  )
  io.println("[OK] Templates created")

  use wf_bug_id <- result.try(insert_workflow(db, org_id, alpha_id, "Bug Resolution", admin_id))
  use wf_feature_id <- result.try(insert_workflow(db, org_id, alpha_id, "Feature Development", admin_id))
  use wf_card_id <- result.try(insert_workflow(db, org_id, alpha_id, "Card Automation", admin_id))
  io.println("[OK] Workflows created")

  use rule_bug_resolved <- result.try(insert_rule(db, wf_bug_id, "On Bug Resolved", "task", Some(alpha_bug_type), "resolved"))
  use _ <- result.try(attach_template(db, rule_bug_resolved, alpha_qa_tmpl))

  use rule_bug_closed <- result.try(insert_rule(db, wf_bug_id, "On Bug Closed", "task", Some(alpha_bug_type), "closed"))
  use _ <- result.try(attach_template(db, rule_bug_closed, alpha_deploy_tmpl))

  use rule_feature_done <- result.try(insert_rule(db, wf_feature_id, "On Feature Done", "task", Some(alpha_feature_type), "done"))
  use _ <- result.try(attach_template(db, rule_feature_done, alpha_review_tmpl))

  use rule_feature_qa <- result.try(insert_rule(db, wf_feature_id, "On Feature QA Approved", "task", Some(alpha_feature_type), "qa_approved"))
  use _ <- result.try(attach_template(db, rule_feature_qa, alpha_deploy_tmpl))

  use _rule_card <- result.try(insert_rule(db, wf_card_id, "On Card Archived", "card", None, "archived"))
  io.println("[OK] Rules created")

  // =========================================================================
  // Project Beta (beta user is manager, admin is also manager)
  // =========================================================================
  io.println("\n--- Creating Project Beta ---")

  use beta_id <- result.try(insert_project(db, org_id, "Project Beta"))
  // admin@example.com as manager (Org Admin)
  use _ <- result.try(insert_member(db, beta_id, admin_id, "manager"))
  // beta@example.com as manager (Org Member who is only manager on Beta)
  use _ <- result.try(insert_member(db, beta_id, beta_user_id, "manager"))
  use beta_bug_type <- result.try(insert_task_type(db, beta_id, "Bug", "bug-ant"))
  use _beta_feature <- result.try(insert_task_type(db, beta_id, "Feature", "sparkles"))
  use wf_beta_id <- result.try(insert_workflow(db, org_id, beta_id, "Simple Bug Flow", admin_id))
  use _rule_beta <- result.try(insert_rule(db, wf_beta_id, "On Beta Bug Resolved", "task", Some(beta_bug_type), "resolved"))
  io.println("[OK] Project Beta created")
  io.println("[OK] Beta members: admin (manager), beta (manager)")

  // =========================================================================
  // Tasks and Cards
  // =========================================================================
  io.println("\n--- Creating Tasks and Cards ---")

  // Alpha: Create cards with colors
  use card_sprint <- result.try(insert_card(db, alpha_id, "Sprint Notes", Some("blue"), admin_id))
  use card_arch <- result.try(insert_card(db, alpha_id, "Architecture", Some("purple"), admin_id))
  use card_retro <- result.try(insert_card(db, alpha_id, "Retro", Some("green"), admin_id))
  use card_release <- result.try(insert_card(db, alpha_id, "Release", Some("orange"), admin_id))
  let alpha_card_ids = [card_sprint, card_arch, card_retro, card_release]
  io.println("[OK] Alpha cards created (4 cards with colors, last one empty)")

  // Alpha: Bugs - some in cards, some directly in project
  use bug1 <- result.try(insert_task(db, alpha_id, alpha_bug_type, "Login broken", admin_id, Some(card_sprint)))
  use bug2 <- result.try(insert_task(db, alpha_id, alpha_bug_type, "Dashboard slow", admin_id, Some(card_sprint)))
  use bug3 <- result.try(insert_task(db, alpha_id, alpha_bug_type, "Upload fails", admin_id, Some(card_arch)))
  use bug4 <- result.try(insert_task(db, alpha_id, alpha_bug_type, "Timeout", admin_id, None))
  use bug5 <- result.try(insert_task(db, alpha_id, alpha_bug_type, "Email delayed", admin_id, None))
  let bug_ids = [bug1, bug2, bug3, bug4, bug5]
  io.println("[OK] Alpha bugs: 3 in cards, 2 directly in project")

  // Alpha: Features - some in cards, some directly in project
  use feat1 <- result.try(insert_task(db, alpha_id, alpha_feature_type, "Dark mode", admin_id, Some(card_arch)))
  use feat2 <- result.try(insert_task(db, alpha_id, alpha_feature_type, "Export PDF", admin_id, Some(card_retro)))
  use feat3 <- result.try(insert_task(db, alpha_id, alpha_feature_type, "Notifications", admin_id, None))
  let feature_ids = [feat1, feat2, feat3]
  io.println("[OK] Alpha features: 2 in cards, 1 directly in project")

  let card_ids = alpha_card_ids

  // Beta: Create cards with colors
  use beta_card1 <- result.try(insert_card(db, beta_id, "Backend Refactor", Some("red"), admin_id))
  use beta_card2 <- result.try(insert_card(db, beta_id, "API Cleanup", Some("yellow"), admin_id))
  use beta_card3 <- result.try(insert_card(db, beta_id, "DB Migration", Some("pink"), admin_id))
  use beta_card_empty <- result.try(insert_card(db, beta_id, "Docs", Some("gray"), admin_id))
  let beta_card_ids = [beta_card1, beta_card2, beta_card3, beta_card_empty]
  io.println("[OK] Beta cards created (4 cards with colors, last one empty)")

  // Beta: Bugs - some in cards, some directly in project
  use beta_bug1 <- result.try(insert_task(db, beta_id, beta_bug_type, "Beta Bug 1", admin_id, Some(beta_card1)))
  use beta_bug2 <- result.try(insert_task(db, beta_id, beta_bug_type, "Beta Bug 2", admin_id, Some(beta_card2)))
  use beta_bug3 <- result.try(insert_task(db, beta_id, beta_bug_type, "Beta Bug 3", admin_id, Some(beta_card3)))
  use beta_bug4 <- result.try(insert_task(db, beta_id, beta_bug_type, "Beta Bug 4", admin_id, None))
  let beta_bug_ids = [beta_bug1, beta_bug2, beta_bug3, beta_bug4]
  io.println("[OK] Beta bugs: 3 in cards, 1 directly in project")

  io.println("[OK] Tasks and cards created")

  // =========================================================================
  // Task Events (for Project Metrics)
  // =========================================================================
  io.println("\n--- Creating Task Events ---")
  let all_alpha_tasks = list.flatten([bug_ids, feature_ids])
  let all_beta_tasks = beta_bug_ids
  let mut_events = 0

  // All tasks: task_created events
  use _ <- result.try(list.try_map(all_alpha_tasks, fn(id) {
    insert_task_event(db, org_id, alpha_id, id, admin_id, "task_created")
  }))
  use _ <- result.try(list.try_map(all_beta_tasks, fn(id) {
    insert_task_event(db, org_id, beta_id, id, admin_id, "task_created")
  }))
  let events_count = mut_events + list.length(all_alpha_tasks) + list.length(all_beta_tasks)
  io.println("[OK] Created events: " <> int.to_string(list.length(all_alpha_tasks) + list.length(all_beta_tasks)))

  // Claim most tasks (7 of 10)
  let to_claim_alpha = list.take(all_alpha_tasks, 6)
  let to_claim_beta = list.take(all_beta_tasks, 1)
  use _ <- result.try(list.try_map(to_claim_alpha, fn(id) {
    use _ <- result.try(insert_task_event(db, org_id, alpha_id, id, admin_id, "task_claimed"))
    update_task_status(db, id, "claimed", Some(admin_id))
  }))
  use _ <- result.try(list.try_map(to_claim_beta, fn(id) {
    use _ <- result.try(insert_task_event(db, org_id, beta_id, id, admin_id, "task_claimed"))
    update_task_status(db, id, "claimed", Some(admin_id))
  }))
  let events_count = events_count + list.length(to_claim_alpha) + list.length(to_claim_beta)
  io.println("[OK] Claimed events: " <> int.to_string(list.length(to_claim_alpha) + list.length(to_claim_beta)))

  // Release some tasks (2)
  let to_release = list.take(to_claim_alpha, 2)
  use _ <- result.try(list.try_map(to_release, fn(id) {
    use _ <- result.try(insert_task_event(db, org_id, alpha_id, id, admin_id, "task_released"))
    update_task_status(db, id, "available", None)
  }))
  let events_count = events_count + list.length(to_release)
  io.println("[OK] Released events: " <> int.to_string(list.length(to_release)))

  // Complete some tasks (4)
  let to_complete_alpha = list.drop(to_claim_alpha, 2) |> list.take(3)
  let to_complete_beta = to_claim_beta
  use _ <- result.try(list.try_map(to_complete_alpha, fn(id) {
    use _ <- result.try(insert_task_event(db, org_id, alpha_id, id, admin_id, "task_completed"))
    update_task_status(db, id, "completed", None)
  }))
  use _ <- result.try(list.try_map(to_complete_beta, fn(id) {
    use _ <- result.try(insert_task_event(db, org_id, beta_id, id, admin_id, "task_completed"))
    update_task_status(db, id, "completed", None)
  }))
  let events_count = events_count + list.length(to_complete_alpha) + list.length(to_complete_beta)
  io.println("[OK] Completed events: " <> int.to_string(list.length(to_complete_alpha) + list.length(to_complete_beta)))

  // =========================================================================
  // Trigger Rule Executions
  // =========================================================================
  io.println("\n--- Triggering Rule Executions ---")

  let mut_count = 0

  // Resolve bugs
  let resolved = list.take(bug_ids, 3)
  use _ <- result.try(list.try_map(resolved, fn(id) {
    rules_engine.evaluate_rules(db, StateChangeEvent(Task, id, Some("in_progress"), "resolved", alpha_id, org_id, admin_id, True, Some(alpha_bug_type)))
    |> result.map_error(fn(_) { "eval failed" })
  }))
  let count = mut_count + list.length(resolved)
  io.println("[OK] Bug resolved: " <> int.to_string(list.length(resolved)))

  // Close bugs
  let closed = list.take(bug_ids, 2)
  use _ <- result.try(list.try_map(closed, fn(id) {
    rules_engine.evaluate_rules(db, StateChangeEvent(Task, id, Some("resolved"), "closed", alpha_id, org_id, admin_id, True, Some(alpha_bug_type)))
    |> result.map_error(fn(_) { "eval failed" })
  }))
  let count = count + list.length(closed)
  io.println("[OK] Bug closed: " <> int.to_string(list.length(closed)))

  // Feature done
  let done = list.take(feature_ids, 2)
  use _ <- result.try(list.try_map(done, fn(id) {
    rules_engine.evaluate_rules(db, StateChangeEvent(Task, id, Some("in_progress"), "done", alpha_id, org_id, admin_id, True, Some(alpha_feature_type)))
    |> result.map_error(fn(_) { "eval failed" })
  }))
  let count = count + list.length(done)
  io.println("[OK] Feature done: " <> int.to_string(list.length(done)))

  // Feature QA
  let assert [first_feature, ..] = feature_ids
  use _ <- result.try(
    rules_engine.evaluate_rules(db, StateChangeEvent(Task, first_feature, Some("done"), "qa_approved", alpha_id, org_id, admin_id, True, Some(alpha_feature_type)))
    |> result.map_error(fn(_) { "eval failed" })
  )
  let count = count + 1
  io.println("[OK] Feature QA approved: 1")

  // Card archived
  let archived = list.take(card_ids, 2)
  use _ <- result.try(list.try_map(archived, fn(id) {
    rules_engine.evaluate_rules(db, StateChangeEvent(Card, id, Some("active"), "archived", alpha_id, org_id, admin_id, True, None))
    |> result.map_error(fn(_) { "eval failed" })
  }))
  let count = count + list.length(archived)
  io.println("[OK] Card archived: " <> int.to_string(list.length(archived)))

  // Beta bugs
  use _ <- result.try(list.try_map(beta_bug_ids, fn(id) {
    rules_engine.evaluate_rules(db, StateChangeEvent(Task, id, Some("in_progress"), "resolved", beta_id, org_id, admin_id, True, Some(beta_bug_type)))
    |> result.map_error(fn(_) { "eval failed" })
  }))
  let count = count + list.length(beta_bug_ids)
  io.println("[OK] Beta bugs resolved: " <> int.to_string(list.length(beta_bug_ids)))

  // Idempotent
  let assert [first_bug, ..] = bug_ids
  use _ <- result.try(
    rules_engine.evaluate_rules(db, StateChangeEvent(Task, first_bug, Some("claimed"), "resolved", alpha_id, org_id, admin_id, True, Some(alpha_bug_type)))
    |> result.map_error(fn(_) { "eval failed" })
  )
  let count = count + 1
  io.println("[OK] Idempotent test: 1")

  Ok(SeedStats(
    projects: 2,
    users: 4,  // admin, pm, member, beta
    task_types: 5,
    workflows: 4,
    rules: 6,
    tasks: list.length(bug_ids) + list.length(feature_ids) + list.length(beta_bug_ids),
    cards: list.length(card_ids) + list.length(beta_card_ids),
    rule_executions: count,
    task_events: events_count,
  ))
}

// =============================================================================
// Environment
// =============================================================================

fn database_url() -> Result(String, String) {
  case getenv("DATABASE_URL", "") {
    "" -> Error("DATABASE_URL environment variable not set")
    url -> Ok(url)
  }
}

fn getenv(key: String, default: String) -> String {
  getenv_charlist(charlist.from_string(key), charlist.from_string(default))
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(key: charlist.Charlist, default: charlist.Charlist) -> charlist.Charlist

// =============================================================================
// Database Helpers
// =============================================================================

fn reset_workflow_tables(db: pog.Connection) -> Result(Nil, String) {
  // First truncate tables with foreign keys
  use _ <- result.try(
    pog.query("TRUNCATE rule_templates, rule_executions, rules, workflows, task_templates, task_events, tasks, task_types, cards, project_members, projects CASCADE")
    |> pog.execute(db)
    |> result.map(fn(_) { Nil })
    |> result.map_error(fn(e) { "Truncate failed: " <> string.inspect(e) })
  )
  // Re-create Default project
  pog.query("INSERT INTO projects (id, org_id, name) VALUES (1, 1, 'Default') ON CONFLICT (id) DO NOTHING")
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "Reset default project failed: " <> string.inspect(e) })
}

fn query_int(db: pog.Connection, sql: String) -> Result(Int, String) {
  pog.query(sql)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Query failed: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [v] -> Ok(v) _ -> Error("No rows") } })
}

fn int_decoder() {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}

/// Insert or update a user. Uses a fixed password hash for "passwordpassword".
fn upsert_user(db: pog.Connection, org_id: Int, email: String, org_role: String) -> Result(Int, String) {
  // Password hash for "passwordpassword" (generated with argon2)
  let password_hash = "$argon2id$v=19$m=19456,t=2,p=1$Dqfb9+7qAiJzB5ghwAjP8A$3agIFIqxEfklBQ4Y+kbetHBD2hyyPZyEfqC8GPwkhDY"

  pog.query(
    "INSERT INTO users (email, password_hash, org_id, org_role)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (email) DO UPDATE SET org_role = $4
     RETURNING id"
  )
  |> pog.parameter(pog.text(email))
  |> pog.parameter(pog.text(password_hash))
  |> pog.parameter(pog.int(org_id))
  |> pog.parameter(pog.text(org_role))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Upsert user " <> email <> ": " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID for " <> email) } })
}

fn insert_project(db: pog.Connection, org_id: Int, name: String) -> Result(Int, String) {
  pog.query("INSERT INTO projects (org_id, name) VALUES ($1, $2) RETURNING id")
  |> pog.parameter(pog.int(org_id))
  |> pog.parameter(pog.text(name))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Insert project: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID") } })
}

fn insert_member(db: pog.Connection, project_id: Int, user_id: Int, role: String) -> Result(Nil, String) {
  pog.query("INSERT INTO project_members (project_id, user_id, role) VALUES ($1, $2, $3)")
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.text(role))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "Insert member: " <> string.inspect(e) })
}

fn insert_task_type(db: pog.Connection, project_id: Int, name: String, icon: String) -> Result(Int, String) {
  pog.query("INSERT INTO task_types (project_id, name, icon) VALUES ($1, $2, $3) RETURNING id")
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.text(icon))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Insert task_type: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID") } })
}

fn insert_template(db: pog.Connection, org_id: Int, project_id: Int, type_id: Int, name: String, created_by: Int) -> Result(Int, String) {
  pog.query("INSERT INTO task_templates (org_id, project_id, type_id, name, description, priority, created_by) VALUES ($1, $2, $3, $4, 'Seeded', 3, $5) RETURNING id")
  |> pog.parameter(pog.int(org_id))
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(type_id))
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.int(created_by))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Insert template: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID") } })
}

fn insert_workflow(db: pog.Connection, org_id: Int, project_id: Int, name: String, created_by: Int) -> Result(Int, String) {
  pog.query("INSERT INTO workflows (org_id, project_id, name, active, created_by) VALUES ($1, $2, $3, true, $4) RETURNING id")
  |> pog.parameter(pog.int(org_id))
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.int(created_by))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Insert workflow: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID") } })
}

fn insert_rule(db: pog.Connection, workflow_id: Int, name: String, resource_type: String, task_type_id: Option(Int), to_state: String) -> Result(Int, String) {
  pog.query("INSERT INTO rules (workflow_id, name, resource_type, task_type_id, to_state, active) VALUES ($1, $2, $3, $4, $5, true) RETURNING id")
  |> pog.parameter(pog.int(workflow_id))
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.text(resource_type))
  |> pog.parameter(pog.nullable(pog.int, task_type_id))
  |> pog.parameter(pog.text(to_state))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Insert rule: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID") } })
}

fn attach_template(db: pog.Connection, rule_id: Int, template_id: Int) -> Result(Nil, String) {
  pog.query("INSERT INTO rule_templates (rule_id, template_id, execution_order) VALUES ($1, $2, 1)")
  |> pog.parameter(pog.int(rule_id))
  |> pog.parameter(pog.int(template_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "Attach template: " <> string.inspect(e) })
}

fn insert_task(db: pog.Connection, project_id: Int, type_id: Int, title: String, created_by: Int, card_id: Option(Int)) -> Result(Int, String) {
  pog.query("INSERT INTO tasks (project_id, type_id, title, description, priority, status, created_by, card_id) VALUES ($1, $2, $3, 'Seeded', 3, 'available', $4, $5) RETURNING id")
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(type_id))
  |> pog.parameter(pog.text(title))
  |> pog.parameter(pog.int(created_by))
  |> pog.parameter(pog.nullable(pog.int, card_id))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Insert task: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID") } })
}

fn insert_card(db: pog.Connection, project_id: Int, title: String, color: Option(String), created_by: Int) -> Result(Int, String) {
  pog.query("INSERT INTO cards (project_id, title, description, color, created_by) VALUES ($1, $2, 'Seeded', $3, $4) RETURNING id")
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.text(title))
  |> pog.parameter(pog.nullable(pog.text, color))
  |> pog.parameter(pog.int(created_by))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Insert card: " <> string.inspect(e) })
  |> result.try(fn(r) { case r.rows { [id] -> Ok(id) _ -> Error("No ID") } })
}

fn insert_task_event(db: pog.Connection, org_id: Int, project_id: Int, task_id: Int, user_id: Int, event_type: String) -> Result(Nil, String) {
  pog.query("INSERT INTO task_events (org_id, project_id, task_id, actor_user_id, event_type) VALUES ($1, $2, $3, $4, $5)")
  |> pog.parameter(pog.int(org_id))
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(task_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.text(event_type))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "Insert task_event: " <> string.inspect(e) })
}

fn update_task_status(db: pog.Connection, task_id: Int, status: String, claimed_by: Option(Int)) -> Result(Nil, String) {
  case claimed_by {
    Some(claimed_user_id) -> {
      pog.query("UPDATE tasks SET status = $1, claimed_by = $2, claimed_at = NOW() WHERE id = $3")
      |> pog.parameter(pog.text(status))
      |> pog.parameter(pog.int(claimed_user_id))
      |> pog.parameter(pog.int(task_id))
      |> pog.execute(db)
      |> result.map(fn(_) { Nil })
      |> result.map_error(fn(e) { "Update task: " <> string.inspect(e) })
    }
    None -> {
      pog.query("UPDATE tasks SET status = $1, completed_at = NOW() WHERE id = $2")
      |> pog.parameter(pog.text(status))
      |> pog.parameter(pog.int(task_id))
      |> pog.execute(db)
      |> result.map(fn(_) { Nil })
      |> result.map_error(fn(e) { "Update task: " <> string.inspect(e) })
    }
  }
}
