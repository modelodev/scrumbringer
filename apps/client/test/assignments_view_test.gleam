import gleam/dict
import support/domain_fixtures
import support/render_assertions

import domain/metrics.{
  NoSample, OrgMetricsOverview, OrgMetricsProjectOverview,
  OrgMetricsUserOverview, WindowDays,
}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/project.{type Project, type ProjectMember, Project, ProjectMember}
import domain/project_role.{type ProjectRole, Manager}
import domain/remote.{Loaded}
import domain/user.{User}
import gleam/option as opt
import gleam/set
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/features/assignments/components/project_card
import scrumbringer_client/features/assignments/components/user_card
import scrumbringer_client/features/assignments/view as assignments_view
import scrumbringer_client/features/projects/view as projects_view

fn render_assignments(model: client_state.Model) -> String {
  assignments_view.view_assignments(config_from_model(model))
  |> render_assertions.html
}

fn config_from_model(
  model: client_state.Model,
) -> assignments_view.Config(String) {
  assignments_view.Config(
    locale: model.ui.locale,
    assignments: model.admin.assignments,
    projects: model.core.projects,
    org_users: model.admin.members.org_users_cache,
    project_card: project_card_config(model),
    user_card: user_card_config(model),
    on_view_mode_changed: fn(_) { "view-mode" },
    on_search_changed: fn(value) { "search:" <> value },
    on_search_debounced: fn(value) { "search-debounced:" <> value },
    on_project_create_clicked: "create-project",
    on_invites_clicked: "invites",
    project_dialogs: projects_dialogs_config(model),
  )
}

fn projects_dialogs_config(
  model: client_state.Model,
) -> projects_view.Config(String) {
  projects_view.Config(
    locale: model.ui.locale,
    projects: model.core.projects,
    project_dialog: model.admin.projects,
    on_create_dialog_opened: "project-create-open",
    on_create_dialog_closed: "project-create-close",
    on_create_submitted: "project-create-submit",
    on_create_next_clicked: "project-create-next",
    on_create_back_clicked: "project-create-back",
    on_create_name_changed: fn(value) { "project-create-name:" <> value },
    on_create_max_depth_changed: fn(value) { "project-create-depth:" <> value },
    on_create_healthy_pool_limit_changed: fn(value) {
      "project-create-limit:" <> value
    },
    on_create_depth_singular_changed: fn(_, value) {
      "project-create-singular:" <> value
    },
    on_create_depth_plural_changed: fn(_, value) {
      "project-create-plural:" <> value
    },
    on_edit_dialog_opened: fn(_, _, _, _) { "project-edit-open" },
    on_edit_dialog_closed: "project-edit-close",
    on_edit_submitted: "project-edit-submit",
    on_edit_name_changed: fn(value) { "project-edit-name:" <> value },
    on_edit_max_depth_changed: fn(value) { "project-edit-depth:" <> value },
    on_edit_healthy_pool_limit_changed: fn(value) {
      "project-edit-limit:" <> value
    },
    on_edit_depth_singular_changed: fn(_, value) {
      "project-edit-singular:" <> value
    },
    on_edit_depth_plural_changed: fn(_, value) {
      "project-edit-plural:" <> value
    },
    on_edit_depth_reduction_review_clicked: "project-edit-depth-review",
    on_edit_depth_reduction_confirmed: "project-edit-depth-confirm",
    on_delete_confirm_opened: fn(_, _) { "project-delete-open" },
    on_delete_confirm_closed: "project-delete-close",
    on_delete_submitted: "project-delete-submit",
  )
}

fn project_card_config(model: client_state.Model) -> project_card.Config(String) {
  project_card.Config(
    locale: model.ui.locale,
    assignments: model.admin.assignments,
    current_user_id: case model.core.user {
      opt.Some(User(id: id, ..)) -> opt.Some(id)
      opt.None -> opt.None
    },
    org_users: model.admin.members.org_users_cache,
    metrics: model.admin.metrics.admin_metrics_overview,
    on_project_toggled: fn(_) { "project-toggle" },
    on_inline_add_started: fn(_) { "inline-add-start" },
    on_role_changed: fn(_, _, _role: ProjectRole) { "role-change" },
    on_remove_confirmed: "remove-confirm",
    on_remove_cancelled: "remove-cancel",
    on_remove_clicked: fn(_, _) { "remove-click" },
    on_inline_add_search_changed: fn(value) { "inline-search:" <> value },
    on_inline_add_selection_changed: fn(value) { "inline-select:" <> value },
    on_inline_add_role_changed: fn(_role) { "inline-role" },
    on_inline_add_cancelled: "inline-cancel",
    on_inline_add_submitted: "inline-submit",
    noop: "noop",
  )
}

fn user_card_config(model: client_state.Model) -> user_card.Config(String) {
  user_card.Config(
    locale: model.ui.locale,
    assignments: model.admin.assignments,
    all_projects: model.core.projects,
    metrics: model.admin.metrics.admin_metrics_users,
    on_user_toggled: fn(_) { "user-toggle" },
    on_inline_add_started: fn(_) { "inline-add-start" },
    on_role_changed: fn(_, _, _role: ProjectRole) { "role-change" },
    on_remove_confirmed: "remove-confirm",
    on_remove_cancelled: "remove-cancel",
    on_remove_clicked: fn(_, _) { "remove-click" },
    on_inline_add_selection_changed: fn(value) { "inline-select:" <> value },
    on_inline_add_role_changed: fn(_role) { "inline-role" },
    on_inline_add_cancelled: "inline-cancel",
    on_inline_add_submitted: "inline-submit",
    noop: "noop",
  )
}

fn base_model() -> client_state.Model {
  client_state.default_model()
}

fn sample_project(id: Int, name: String) -> Project {
  Project(..domain_fixtures.project(id, name), members_count: 0)
}

fn manager_member(user_id: Int) -> ProjectMember {
  ProjectMember(..domain_fixtures.project_member(user_id), role: Manager)
}

pub fn filter_projects_by_name_test() {
  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(
        ..core,
        projects: Loaded([
          sample_project(1, "Project Alpha"),
          sample_project(2, "Project Beta"),
        ]),
      )
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
          search_query: "alpha",
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "Project Alpha")
  render_assertions.not_contains(html, "Project Beta")
}

pub fn project_collapsed_hides_members_test() {
  let project = sample_project(1, "Project Alpha")
  let member = manager_member(2)
  let org_user = domain_fixtures.org_user(2, "member@example.com")

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([org_user]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          project_members: dict.from_list([
            #(project.id, Loaded([member])),
          ]),
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.not_contains(html, "member@example.com")
}

pub fn project_expanded_shows_members_test() {
  let project = sample_project(1, "Project Alpha")
  let member = manager_member(2)
  let org_user = domain_fixtures.org_user(2, "member@example.com")

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([org_user]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          project_members: dict.from_list([
            #(project.id, Loaded([member])),
          ]),
          expanded_projects: set.insert(
            admin.assignments.expanded_projects,
            project.id,
          ),
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "member@example.com")
}

pub fn user_without_projects_shows_badge_test() {
  let user = domain_fixtures.org_user(9, "nuevo@example.com")

  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([user]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
          user_projects: dict.insert(dict.new(), user.id, Loaded([])),
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "NO PROJECTS")
}

pub fn project_without_members_shows_badge_test() {
  let project = sample_project(3, "Project Gamma")

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
          project_members: dict.from_list([
            #(project.id, Loaded([])),
          ]),
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "NO MEMBERS")
}

pub fn project_metrics_summary_renders_counts_test() {
  let project = sample_project(1, "Project Alpha")
  let overview =
    OrgMetricsOverview(
      window_days: WindowDays(30),
      available_count: 3,
      claimed_count: 2,
      ongoing_count: 1,
      released_count: 1,
      closed_count: 2,
      release_rate_percent: opt.Some(50),
      pool_flow_ratio_percent: opt.Some(80),
      time_to_first_claim: NoSample,
      time_to_first_claim_buckets: [],
      release_rate_buckets: [],
      wip_count: 2,
      avg_claim_to_complete_ms: opt.None,
      avg_time_in_claimed_ms: opt.None,
      stale_claims_count: 0,
      by_project: [
        OrgMetricsProjectOverview(
          project_id: project.id,
          project_name: project.name,
          available_count: 3,
          claimed_count: 2,
          ongoing_count: 1,
          released_count: 1,
          closed_count: 2,
          release_rate_percent: opt.Some(50),
          pool_flow_ratio_percent: opt.Some(80),
          wip_count: 2,
          avg_claim_to_complete_ms: opt.None,
          avg_time_in_claimed_ms: opt.None,
          stale_claims_count: 0,
        ),
      ],
    )

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        metrics: admin_metrics.Model(
          ..admin.metrics,
          admin_metrics_overview: Loaded(overview),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
          expanded_projects: set.insert(
            admin.assignments.expanded_projects,
            project.id,
          ),
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "assignments-task-metric")
  render_assertions.contains(html, "task-metric-chip is-compact")
  render_assertions.contains(html, "title=\"Available: 3\"")
  render_assertions.contains(html, "title=\"Ongoing: 1\"")
  render_assertions.contains(html, "title=\"Closed: 2\"")
  render_assertions.not_contains(html, "task-metric-chip-label")
  render_assertions.contains(html, "Release %: 50%")
}

pub fn user_metrics_summary_renders_counts_test() {
  let user = domain_fixtures.org_user(9, "member@example.com")
  let metrics =
    OrgMetricsUserOverview(
      user_id: user.id,
      email: user.email,
      claimed_count: 4,
      released_count: 1,
      closed_count: 2,
      ongoing_count: 1,
      last_claim_at: opt.Some("2026-01-02"),
    )

  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([user]),
        ),
        metrics: admin_metrics.Model(
          ..admin.metrics,
          admin_metrics_users: Loaded([metrics]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
          user_projects: dict.insert(dict.new(), user.id, Loaded([])),
          expanded_users: set.insert(admin.assignments.expanded_users, user.id),
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "assignments-task-metric")
  render_assertions.contains(html, "task-metric-chip is-compact")
  render_assertions.contains(html, "title=\"Claimed: 4\"")
  render_assertions.contains(html, "Released: 1")
  render_assertions.contains(html, "title=\"Closed: 2\"")
  render_assertions.contains(html, "title=\"Ongoing: 1\"")
  render_assertions.not_contains(html, "task-metric-chip-label")
  render_assertions.contains(html, "Last claim: 2026-01-02")
}

pub fn empty_state_when_no_projects_test() {
  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: Loaded([]))
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "No projects yet")
  render_assertions.contains(html, "Create Project")
}

pub fn empty_state_when_no_users_test() {
  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "No people yet")
  render_assertions.contains(html, "Create invite link")
}

pub fn empty_state_when_only_admin_user_test() {
  let admin =
    User(..domain_fixtures.user(1, "admin@example.com"), org_role: Admin)
  let admin_org_user =
    OrgUser(..domain_fixtures.org_user(1, "admin@example.com"), org_role: Admin)

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, user: opt.Some(admin))
    })
    |> client_state.update_admin(fn(admin_model) {
      admin_state.AdminModel(
        ..admin_model,
        members: admin_members.Model(
          ..admin_model.members,
          org_users_cache: Loaded([admin_org_user]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin_model.assignments,
          view_mode: assignments_view_mode.ByUser,
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "No people yet")
  render_assertions.contains(html, "Create invite link")
}

pub fn filter_users_by_email_test() {
  let user_admin =
    OrgUser(..domain_fixtures.org_user(1, "admin@example.com"), org_role: Admin)
  let user_member = domain_fixtures.org_user(2, "member@example.com")

  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([user_admin, user_member]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
          search_query: "admin",
          user_projects: dict.from_list([
            #(user_admin.id, Loaded([])),
            #(user_member.id, Loaded([])),
          ]),
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "admin@example.com")
  render_assertions.not_contains(html, "member@example.com")
}

pub fn assignments_renders_table_layout_project_mode_test() {
  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(
        ..core,
        projects: Loaded([
          sample_project(1, "Project Alpha"),
        ]),
      )
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
        ),
      )
    })

  let html = render_assignments(model)

  render_assertions.contains(html, "section admin-surface")
  render_assertions.contains(html, "admin-surface-filters")
  render_assertions.contains(html, "table assignments-table")
}

pub fn assignments_expansion_row_toggles_test() {
  let project = sample_project(1, "Project Alpha")
  let member = manager_member(2)
  let org_user = domain_fixtures.org_user(2, "member@example.com")

  let collapsed_model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([org_user]),
        ),
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          project_members: dict.from_list([
            #(project.id, Loaded([member])),
          ]),
        ),
      )
    })

  let expanded_model =
    collapsed_model
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        assignments: assignments_state.AssignmentsModel(
          ..admin.assignments,
          expanded_projects: set.insert(admin.assignments.expanded_projects, 1),
        ),
      )
    })

  let collapsed_html = render_assignments(collapsed_model)
  let expanded_html = render_assignments(expanded_model)

  render_assertions.not_contains(collapsed_html, "expansion-row")
  render_assertions.contains(expanded_html, "expansion-row")
}
