import gleam/option.{None, Some}

import domain/org_role
import domain/project.{type Project, Project}
import domain/project_role
import domain/user.{type User, User}
import scrumbringer_client/features/milestones/access

fn user(role: org_role.OrgRole) -> User {
  User(
    id: 1,
    email: "user@example.com",
    org_id: 1,
    org_role: role,
    created_at: "2026-02-06T00:00:00Z",
  )
}

fn project(role: project_role.ProjectRole) -> Project {
  Project(
    id: 1,
    name: "Project",
    my_role: role,
    created_at: "2026-02-06T00:00:00Z",
    members_count: 1,
  )
}

pub fn milestones_access_allows_org_admin_without_selected_project_test() {
  let assert True = access.can_manage(Some(user(org_role.Admin)), None)
}

pub fn milestones_access_allows_project_manager_test() {
  let assert True =
    access.can_manage(
      Some(user(org_role.Member)),
      Some(project(project_role.Manager)),
    )
}

pub fn milestones_access_rejects_project_member_test() {
  let assert False =
    access.can_manage(
      Some(user(org_role.Member)),
      Some(project(project_role.Member)),
    )
}

pub fn milestones_access_rejects_missing_user_test() {
  let assert False =
    access.can_manage(None, Some(project(project_role.Manager)))
}

pub fn milestones_access_rejects_member_without_selected_project_test() {
  let assert False = access.can_manage(Some(user(org_role.Member)), None)
}
