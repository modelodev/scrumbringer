//// Static seed data pools and pure helpers used by scenario builders.

import gleam/int

/// Pool of realistic task titles.
pub fn task_titles() -> List(String) {
  [
    "Refine checkout acceptance criteria", "Design payment error states",
    "Build responsive checkout layout", "Implement checkout summary",
    "Expose order pricing API", "Run checkout regression pack",
    "Clarify refund edge cases", "Prototype saved payment method",
    "Slice account settings layout", "Implement notification preferences",
    "Add profile preferences endpoint", "Verify account settings flow",
    "Prepare sprint review notes", "Triage customer login bug",
    "Document API contract changes", "Tune search results performance",
    "Improve cache invalidation strategy", "Add database index migration",
    "Harden form validation errors", "Update release checklist",
  ]
}

/// Pool of realistic card titles.
pub fn card_titles() -> List(String) {
  [
    "Sprint Planning", "Checkout MVP", "Account Settings", "Search Iteration",
    "Release Readiness", "Architecture Decisions", "UX Discovery",
    "Regression Stabilization", "Observability", "Documentation",
  ]
}

/// Pool of user emails for generated users.
pub fn user_emails() -> List(String) {
  [
    "analyst@example.com", "designer@example.com", "markup@example.com",
    "frontend@example.com", "backend@example.com", "qa@example.com",
    "scrum-master@example.com", "product-owner@example.com",
    "devops@example.com", "support@example.com", "data@example.com",
  ]
}

/// Pool of capability names.
pub fn capability_names() -> List(String) {
  [
    "Functional Analysis", "UX Design", "Markup", "Frontend", "Backend", "QA",
    "DevOps", "Product",
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
