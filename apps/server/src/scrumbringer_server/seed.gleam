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
//// DATABASE_URL=... gleam run -m scrumbringer_server/seed -- --realistic
//// DATABASE_URL=... gleam run -m scrumbringer_server/seed -- --minimal
//// ```

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
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

  let config = parse_config_from_args()
  io.println("[OK] Config: " <> config_name(config))

  case run_seed(config) {
    Ok(stats) -> print_summary(stats)
    Error(msg) -> io.println("\n[ERROR] " <> msg)
  }
}

// =============================================================================
// Configuration Parsing
// =============================================================================

fn parse_config_from_args() -> seed_builder.SeedConfig {
  let args = get_args()
  case list.find(args, fn(arg) { arg == "--realistic" }) {
    Ok(_) -> seed_builder.realistic_config()
    Error(_) ->
      case list.find(args, fn(arg) { arg == "--minimal" }) {
        Ok(_) -> seed_builder.minimal_config()
        Error(_) -> seed_builder.default_config()
      }
  }
}

fn config_name(config: seed_builder.SeedConfig) -> String {
  case config.inactive_user_count > 0 {
    True -> "realistic"
    False ->
      case config.user_count <= 2 {
        True -> "minimal"
        False -> "default"
      }
  }
}

@external(erlang, "init", "get_plain_arguments")
fn get_args_raw() -> List(charlist.Charlist)

fn get_args() -> List(String) {
  get_args_raw()
  |> list.map(charlist.to_string)
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

  seed_builder.build_seed(db, org_id, admin_id, config)
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
  io.println("")
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
