import gleam/dict
import gleam/string
import gleeunit/should
import lustre/element

import domain/metrics.{
  NoSample, OrgMetricsOverview, OrgMetricsProjectOverview,
  OrgMetricsUserOverview, WindowDays,
}
import domain/org.{OrgUser}
import domain/org_role.{Admin, Member}
import domain/project.{type Project, Project, ProjectMember}
import domain/project_role.{Manager}
import domain/remote.{Loaded}
import domain/user.{User}
import gleam/option as opt
import gleam/set
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/assignments/view as assignments_view

fn base_model() -> client_state.Model {
  client_state.default_model()
}

fn sample_project(id: Int, name: String) -> Project {
  Project(
    id: id,
    name: name,
    my_role: Manager,
    created_at: "2026-01-01",
    members_count: 0,
  )
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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
          search_query: "alpha",
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "Project Alpha") |> should.be_true
  string.contains(html, "Project Beta") |> should.be_false
}

pub fn project_collapsed_hides_members_test() {
  let project = sample_project(1, "Project Alpha")
  let member =
    ProjectMember(
      user_id: 2,
      role: Manager,
      created_at: "2026-01-01",
      claimed_count: 0,
    )
  let org_user =
    OrgUser(
      id: 2,
      email: "member@example.com",
      org_role: Member,
      created_at: "2026-01-01",
    )

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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          project_members: dict.from_list([
            #(project.id, Loaded([member])),
          ]),
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "member@example.com") |> should.be_false
}

pub fn project_expanded_shows_members_test() {
  let project = sample_project(1, "Project Alpha")
  let member =
    ProjectMember(
      user_id: 2,
      role: Manager,
      created_at: "2026-01-01",
      claimed_count: 0,
    )
  let org_user =
    OrgUser(
      id: 2,
      email: "member@example.com",
      org_role: Member,
      created_at: "2026-01-01",
    )

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
        assignments: state_types.AssignmentsModel(
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

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "member@example.com") |> should.be_true
}

pub fn user_without_projects_shows_badge_test() {
  let user =
    OrgUser(
      id: 9,
      email: "nuevo@example.com",
      org_role: Member,
      created_at: "2026-01-01",
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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
          user_projects: dict.insert(dict.new(), user.id, Loaded([])),
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "NO PROJECTS") |> should.be_true
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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
          project_members: dict.from_list([
            #(project.id, Loaded([])),
          ]),
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "NO MEMBERS") |> should.be_true
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
      completed_count: 2,
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
          completed_count: 2,
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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
          expanded_projects: set.insert(
            admin.assignments.expanded_projects,
            project.id,
          ),
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "Available: 3") |> should.be_true
  string.contains(html, "Ongoing: 1") |> should.be_true
  string.contains(html, "Completed: 2") |> should.be_true
  string.contains(html, "Release %: 50%") |> should.be_true
}

pub fn user_metrics_summary_renders_counts_test() {
  let user =
    OrgUser(
      id: 9,
      email: "member@example.com",
      org_role: Member,
      created_at: "2026-01-01",
    )
  let metrics =
    OrgMetricsUserOverview(
      user_id: user.id,
      email: user.email,
      claimed_count: 4,
      released_count: 1,
      completed_count: 2,
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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
          user_projects: dict.insert(dict.new(), user.id, Loaded([])),
          expanded_users: set.insert(admin.assignments.expanded_users, user.id),
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "Claimed: 4") |> should.be_true
  string.contains(html, "Released: 1") |> should.be_true
  string.contains(html, "Completed: 2") |> should.be_true
  string.contains(html, "Ongoing: 1") |> should.be_true
  string.contains(html, "Last claim: 2026-01-02") |> should.be_true
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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "No projects yet") |> should.be_true
  string.contains(html, "Create Project") |> should.be_true
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
        assignments: state_types.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "No users yet") |> should.be_true
  string.contains(html, "Create invite link") |> should.be_true
}

pub fn empty_state_when_only_admin_user_test() {
  let admin =
    User(
      id: 1,
      email: "admin@example.com",
      org_id: 1,
      org_role: Admin,
      created_at: "2026-01-01",
    )
  let admin_org_user =
    OrgUser(
      id: 1,
      email: "admin@example.com",
      org_role: Admin,
      created_at: "2026-01-01",
    )

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
        assignments: state_types.AssignmentsModel(
          ..admin_model.assignments,
          view_mode: assignments_view_mode.ByUser,
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "No users yet") |> should.be_true
  string.contains(html, "Create invite link") |> should.be_true
}

pub fn filter_users_by_email_test() {
  let user_admin =
    OrgUser(
      id: 1,
      email: "admin@example.com",
      org_role: Admin,
      created_at: "2026-01-01",
    )
  let user_member =
    OrgUser(
      id: 2,
      email: "member@example.com",
      org_role: Member,
      created_at: "2026-01-01",
    )

  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([user_admin, user_member]),
        ),
        assignments: state_types.AssignmentsModel(
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

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "admin@example.com") |> should.be_true
  string.contains(html, "member@example.com") |> should.be_false
}
