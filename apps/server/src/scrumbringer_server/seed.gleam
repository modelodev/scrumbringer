//// Standalone seed module for populating test data.
////
//// ## Mission
////
//// Populate the database with realistic demo data for development and metrics.
////
//// ## Responsibilities
////
//// - Parse CLI arguments for configuration selection
//// - Orchestrate seed execution via seed_builder
//// - Print summary of created data
////
//// ## Non-responsibilities
////
//// - Direct SQL operations (see seed_db.gleam)
//// - Scenario logic (see seed_builder.gleam)
////
//// ## Usage
////
//// ```bash
//// cd apps/server
//// DATABASE_URL=... gleam run -m scrumbringer_server/seed
//// ```

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/result
import scrumbringer_server
import scrumbringer_server/seed_builder
import scrumbringer_server/seed_db

// =============================================================================
// Main Entry Point
// =============================================================================

/// Runs the seed script and prints a summary of generated data.
pub fn main() {
  io.println("\n========================================")
  io.println("  SCRUMBRINGER SEED")
  io.println("========================================\n")

  let config = config_from_env()

  case run_seed(config) {
    Ok(stats) -> print_summary(stats)
    Error(msg) -> io.println("\n[ERROR] " <> msg)
  }
}

// =============================================================================
// Seed Execution
// =============================================================================

fn run_seed(
  config: seed_builder.SeedConfig,
) -> Result(seed_builder.SeedResult, String) {
  use db_url <- result.try(database_url())
  io.println("[OK] DATABASE_URL found")

  use app <- result.try(
    scrumbringer_server.new_app("seed-secret", db_url)
    |> result.map_error(fn(_) { "Failed to connect to database" }),
  )
  let scrumbringer_server.App(db: db, ..) = app
  io.println("[OK] Connected to database")

  use org_id <- result.try(seed_db.query_int(
    db,
    "SELECT id FROM organizations LIMIT 1",
  ))
  use admin_id <- result.try(seed_db.query_int(
    db,
    "SELECT id FROM users WHERE email = 'admin@example.com'",
  ))
  io.println(
    "[OK] Org ID: "
    <> int.to_string(org_id)
    <> ", Admin ID: "
    <> int.to_string(admin_id),
  )

  use _ <- result.try(seed_db.reset_workflow_tables(db))
  io.println("[OK] Reset workflow tables")

  use stats <- result.try(seed_builder.build_seed(db, org_id, admin_id, config))

  use empty_org_id <- result.try(seed_db.insert_organization(db, "Empty Org"))
  use _ <- result.try(seed_db.insert_user_simple(
    db,
    empty_org_id,
    "empty-admin@example.com",
    "admin",
  ))
  io.println("[OK] Empty org created (no projects): empty-admin@example.com")

  Ok(stats)
}

// =============================================================================
// Output
// =============================================================================

fn print_summary(stats: seed_builder.SeedResult) {
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
  io.println("  admin@example.com    - Org Admin")
  io.println("  pm@example.com       - Org Member")
  io.println("  member@example.com   - Org Member")
  io.println("  beta@example.com     - Org Member")
  io.println("  empty-admin@example.com - Org Admin (Empty Org)")
  io.println("")
}

fn config_from_env() -> seed_builder.SeedConfig {
  case getenv("SEED_CONFIG", "realistic") {
    "visual_qa" -> {
      io.println("[OK] Config: visual_qa")
      seed_builder.visual_qa_config()
    }
    _ -> {
      io.println("[OK] Config: realistic")
      seed_builder.realistic_config()
    }
  }
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
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
