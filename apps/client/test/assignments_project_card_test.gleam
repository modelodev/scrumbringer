import gleam/int
import gleam/option as opt
import lustre/element
import support/render_assertions

import domain/metrics.{
  type OrgMetricsOverview, NoSample, OrgMetricsOverview, WindowDays,
}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{type Project, type ProjectMember, Project, ProjectMember}
import domain/project_role.{type ProjectRole, Manager}
import domain/remote
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/features/assignments/components/project_card
import scrumbringer_client/i18n/locale

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

fn member() -> ProjectMember {
  ProjectMember(
    user_id: 7,
    role: Manager,
    created_at: "2026-03-20",
    claimed_count: 0,
  )
}

fn org_user() -> OrgUser {
  OrgUser(
    id: 7,
    email: "member@example.com",
    org_role: org_role.Member,
    created_at: "2026-03-20",
  )
}

fn metrics() -> OrgMetricsOverview {
  OrgMetricsOverview(
    window_days: WindowDays(30),
    available_count: 0,
    claimed_count: 0,
    ongoing_count: 0,
    released_count: 0,
    closed_count: 0,
    release_rate_percent: opt.None,
    pool_flow_ratio_percent: opt.None,
    time_to_first_claim: NoSample,
    time_to_first_claim_buckets: [],
    release_rate_buckets: [],
    wip_count: 0,
    avg_claim_to_complete_ms: opt.None,
    avg_time_in_claimed_ms: opt.None,
    stale_claims_count: 0,
    by_project: [],
  )
}

fn config() -> project_card.Config(String) {
  project_card.Config(
    locale: locale.En,
    assignments: assignments_state.default_model(),
    current_user_id: opt.None,
    org_users: remote.Loaded([org_user()]),
    metrics: remote.Loaded(metrics()),
    on_project_toggled: fn(id) { "toggle:" <> int.to_string(id) },
    on_inline_add_started: fn(_context) { "inline-add-start" },
    on_role_changed: fn(project_id, user_id, _role: ProjectRole) {
      "role:" <> int.to_string(project_id) <> ":" <> int.to_string(user_id)
    },
    on_remove_confirmed: "remove-confirmed",
    on_remove_cancelled: "remove-cancelled",
    on_remove_clicked: fn(project_id, user_id) {
      "remove:" <> int.to_string(project_id) <> ":" <> int.to_string(user_id)
    },
    on_inline_add_search_changed: fn(value) { "search:" <> value },
    on_inline_add_selection_changed: fn(value) { "select:" <> value },
    on_inline_add_role_changed: fn(_role) { "inline-role" },
    on_inline_add_cancelled: "inline-cancel",
    on_inline_add_submitted: "inline-submit",
    noop: "noop",
  )
}

pub fn project_card_renders_expanded_members_from_config_test() {
  let html =
    project_card.view_rows(config(), project(), remote.Loaded([member()]), True)
    |> element.fragment
    |> element.to_document_string

  render_assertions.contains(html, "Platform")
  render_assertions.contains(html, "1 person")
  render_assertions.contains(html, "member@example.com")
  render_assertions.contains(html, "Add member")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "btn-entity-action")
}

pub fn project_card_confirm_remove_uses_semantic_accessible_buttons_test() {
  let assignments =
    assignments_state.AssignmentsModel(
      ..assignments_state.default_model(),
      inline_remove_confirm: opt.Some(#(11, 7)),
    )
  let cfg = project_card.Config(..config(), assignments:)

  let html =
    project_card.view_rows(cfg, project(), remote.Loaded([member()]), True)
    |> element.fragment
    |> element.to_document_string

  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "aria-label=\"Remove: member@example.com\"")
}
