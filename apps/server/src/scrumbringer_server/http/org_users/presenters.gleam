//// JSON presenters for organization user endpoints.

import domain/org_role
import domain/project_role
import gleam/json
import scrumbringer_server/services/org_users_db
import scrumbringer_server/services/projects_db

pub fn users(users: List(org_users_db.OrgUser)) -> json.Json {
  json.array(users, of: user)
}

pub fn users_response(values: List(org_users_db.OrgUser)) -> json.Json {
  json.object([#("users", users(values))])
}

pub fn user(user: org_users_db.OrgUser) -> json.Json {
  let org_users_db.OrgUser(
    id: id,
    email: email,
    org_role: role,
    created_at: created_at,
  ) = user

  json.object([
    #("id", json.int(id)),
    #("email", json.string(email)),
    #("org_role", json.string(org_role.to_string(role))),
    #("created_at", json.string(created_at)),
  ])
}

pub fn user_response(value: org_users_db.OrgUser) -> json.Json {
  json.object([#("user", user(value))])
}

pub fn user_projects(projects: List(projects_db.Project)) -> json.Json {
  json.array(projects, of: user_project)
}

pub fn user_projects_response(values: List(projects_db.Project)) -> json.Json {
  json.object([#("projects", user_projects(values))])
}

fn user_project(project: projects_db.Project) -> json.Json {
  json.object([
    #("id", json.int(project.id)),
    #("name", json.string(project.name)),
    #("role", json.string(project_role.to_string(project.my_role))),
  ])
}

pub fn project_member(
  project_id: Int,
  project_name: String,
  member: projects_db.ProjectMember,
) -> json.Json {
  json.object([
    #("id", json.int(project_id)),
    #("name", json.string(project_name)),
    #("role", json.string(project_role.to_string(member.role))),
  ])
}

pub fn project_member_response(
  project_id: Int,
  project_name: String,
  member: projects_db.ProjectMember,
) -> json.Json {
  json.object([
    #("project", project_member(project_id, project_name, member)),
  ])
}

pub fn project_role_update(
  project_id: Int,
  project_name: String,
  result: projects_db.UpdateMemberRoleResult,
) -> json.Json {
  let projects_db.RoleUpdated(
    user_id: _,
    email: _,
    role: role,
    previous_role: previous_role,
  ) = result

  json.object([
    #("id", json.int(project_id)),
    #("name", json.string(project_name)),
    #("role", json.string(project_role.to_string(role))),
    #("previous_role", json.string(project_role.to_string(previous_role))),
  ])
}

pub fn project_role_update_response(
  project_id: Int,
  project_name: String,
  result: projects_db.UpdateMemberRoleResult,
) -> json.Json {
  json.object([
    #("project", project_role_update(project_id, project_name, result)),
  ])
}

pub fn empty_response() -> json.Json {
  json.object([])
}
