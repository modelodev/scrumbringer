import gleam/dict
import gleam/string
import gleeunit/should
import lustre/element

import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/project.{type Project, Project, ProjectMember}
import domain/project_role.{Manager}
import domain/user.{User}
import gleam/option as opt
import gleam/set
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state
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
        projects: client_state.Loaded([
          sample_project(1, "Project Alpha"),
          sample_project(2, "Project Beta"),
        ]),
      )
    })
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        assignments: client_state.AssignmentsModel(
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
    ProjectMember(user_id: 2, role: Manager, created_at: "2026-01-01")
  let org_user =
    OrgUser(
      id: 2,
      email: "member@example.com",
      org_role: "member",
      created_at: "2026-01-01",
    )

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: client_state.Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        org_users_cache: client_state.Loaded([org_user]),
        assignments: client_state.AssignmentsModel(
          ..admin.assignments,
          project_members: dict.from_list([
            #(project.id, client_state.Loaded([member])),
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
    ProjectMember(user_id: 2, role: Manager, created_at: "2026-01-01")
  let org_user =
    OrgUser(
      id: 2,
      email: "member@example.com",
      org_role: "member",
      created_at: "2026-01-01",
    )

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: client_state.Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        org_users_cache: client_state.Loaded([org_user]),
        assignments: client_state.AssignmentsModel(
          ..admin.assignments,
          project_members: dict.from_list([
            #(project.id, client_state.Loaded([member])),
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
      org_role: "member",
      created_at: "2026-01-01",
    )

  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        org_users_cache: client_state.Loaded([user]),
        assignments: client_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
          user_projects: dict.insert(
            dict.new(),
            user.id,
            client_state.Loaded([]),
          ),
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
      client_state.CoreModel(..core, projects: client_state.Loaded([project]))
    })
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        assignments: client_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByProject,
          project_members: dict.from_list([
            #(project.id, client_state.Loaded([])),
          ]),
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "NO MEMBERS") |> should.be_true
}

pub fn empty_state_when_no_projects_test() {
  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, projects: client_state.Loaded([]))
    })
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        assignments: client_state.AssignmentsModel(
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
      client_state.AdminModel(
        ..admin,
        org_users_cache: client_state.Loaded([]),
        assignments: client_state.AssignmentsModel(
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
      org_role: "admin",
      created_at: "2026-01-01",
    )

  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, user: opt.Some(admin))
    })
    |> client_state.update_admin(fn(admin_model) {
      client_state.AdminModel(
        ..admin_model,
        org_users_cache: client_state.Loaded([admin_org_user]),
        assignments: client_state.AssignmentsModel(
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
      org_role: "admin",
      created_at: "2026-01-01",
    )
  let user_member =
    OrgUser(
      id: 2,
      email: "member@example.com",
      org_role: "member",
      created_at: "2026-01-01",
    )

  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        org_users_cache: client_state.Loaded([user_admin, user_member]),
        assignments: client_state.AssignmentsModel(
          ..admin.assignments,
          view_mode: assignments_view_mode.ByUser,
          search_query: "admin",
          user_projects: dict.from_list([
            #(user_admin.id, client_state.Loaded([])),
            #(user_member.id, client_state.Loaded([])),
          ]),
        ),
      )
    })

  let html =
    assignments_view.view_assignments(model) |> element.to_document_string

  string.contains(html, "admin@example.com") |> should.be_true
  string.contains(html, "member@example.com") |> should.be_false
}
