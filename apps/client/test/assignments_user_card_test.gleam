import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/metrics.{type OrgMetricsUserOverview, OrgMetricsUserOverview}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{type Project, Project}
import domain/project_role.{type ProjectRole, Manager}
import domain/remote
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/features/assignments/components/user_card
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn user() -> OrgUser {
  OrgUser(
    id: 7,
    email: "member@example.com",
    org_role: org_role.Member,
    created_at: "2026-03-20",
  )
}

fn project() -> Project {
  Project(
    id: 11,
    name: "Platform",
    my_role: Manager,
    created_at: "2026-03-20",
    members_count: 1,
    card_depth_names: [],
    healthy_pool_limit: 20,
  )
}

fn metrics() -> OrgMetricsUserOverview {
  OrgMetricsUserOverview(
    user_id: 7,
    email: "member@example.com",
    claimed_count: 2,
    released_count: 1,
    closed_count: 3,
    ongoing_count: 1,
    last_claim_at: opt.Some("2026-03-20T12:00:00Z"),
  )
}

fn config() -> user_card.Config(String) {
  user_card.Config(
    locale: locale.En,
    assignments: assignments_state.default_model(),
    all_projects: remote.Loaded([project()]),
    metrics: remote.Loaded([metrics()]),
    on_user_toggled: fn(id) { "toggle:" <> int.to_string(id) },
    on_inline_add_started: fn(_context) { "inline-add-start" },
    on_role_changed: fn(project_id, user_id, _role: ProjectRole) {
      "role:" <> int.to_string(project_id) <> ":" <> int.to_string(user_id)
    },
    on_remove_confirmed: "remove-confirmed",
    on_remove_cancelled: "remove-cancelled",
    on_remove_clicked: fn(project_id, user_id) {
      "remove:" <> int.to_string(project_id) <> ":" <> int.to_string(user_id)
    },
    on_inline_add_selection_changed: fn(value) { "select:" <> value },
    on_inline_add_role_changed: fn(_role) { "inline-role" },
    on_inline_add_cancelled: "inline-cancel",
    on_inline_add_submitted: "inline-submit",
    noop: "noop",
  )
}

pub fn user_card_renders_expanded_projects_from_config_test() {
  let html =
    user_card.view_rows(config(), user(), remote.Loaded([project()]), True)
    |> element.fragment
    |> element.to_document_string

  assert_contains(html, "member@example.com")
  assert_contains(html, "1 project")
  assert_contains(html, "Platform")
  assert_contains(html, "Add to project")
  assert_contains(html, "assignments-task-metric")
  assert_contains(html, "task-metric-chip is-compact")
  assert_contains(html, "title=\"Claimed: 2\"")
  assert_not_contains(html, "task-metric-chip-label")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-entity-action")
}

pub fn user_card_confirm_remove_uses_semantic_accessible_buttons_test() {
  let assignments =
    assignments_state.AssignmentsModel(
      ..assignments_state.default_model(),
      inline_remove_confirm: opt.Some(#(11, 7)),
    )
  let cfg = user_card.Config(..config(), assignments:)

  let html =
    user_card.view_rows(cfg, user(), remote.Loaded([project()]), True)
    |> element.fragment
    |> element.to_document_string

  assert_contains(html, "btn-danger")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "aria-label=\"Remove: Platform\"")
}
