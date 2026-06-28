//// Static seed data pools and pure helpers used by scenario builders.

import gleam/int

/// Pool of realistic task titles.
pub fn task_titles() -> List(String) {
  [
    "Fix login button", "Dashboard slow", "Upload fails", "Session timeout",
    "Email delayed", "Dark mode support", "Export to PDF", "Notifications",
    "User profile bug", "Search not working", "API rate limiting",
    "Mobile responsive", "Password reset", "Two-factor auth", "Audit logging",
    "Performance tuning", "Cache invalidation", "Database indexing",
    "Error handling", "Input validation",
  ]
}

/// Pool of realistic card titles.
pub fn card_titles() -> List(String) {
  [
    "Sprint Planning", "Architecture", "Retrospective", "Release Notes",
    "Backend Refactor", "API Cleanup", "DB Migration", "Documentation",
    "Security Audit", "Performance",
  ]
}

/// Pool of user emails for generated users.
pub fn user_emails() -> List(String) {
  [
    "member@example.com", "pm@example.com", "beta@example.com",
    "dev@example.com", "qa@example.com", "lead@example.com",
    "intern@example.com", "contractor@example.com", "ops@example.com",
    "design@example.com", "data@example.com",
  ]
}

/// Pool of capability names.
pub fn capability_names() -> List(String) {
  [
    "Engineering", "Product", "Operations", "Security", "Design", "QA",
    "Platform", "Data",
  ]
}

pub fn days_ago_timestamp(days: Int) -> String {
  "NOW() - INTERVAL '" <> int.to_string(days) <> " days'"
}

pub fn list_at(items: List(a), idx: Int, default: a) -> a {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at(rest, n - 1, default)
  }
}
