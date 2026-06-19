//// JSON presenters for project endpoints.

import domain/project.{type ProjectDepthName, ProjectDepthName}
import domain/project_role
import gleam/json
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/projects_db

pub fn projects(projects: List(projects_db.ProjectRecord)) -> json.Json {
  json.array(projects, of: project)
}

pub fn projects_response(values: List(projects_db.ProjectRecord)) -> json.Json {
  json.object([#("projects", projects(values))])
}

pub fn project(project: projects_db.ProjectRecord) -> json.Json {
  let projects_db.ProjectRecord(
    id: id,
    name: name,
    created_at: created_at,
    my_role: my_role,
    members_count: members_count,
    card_depth_names: card_depth_names,
    ..,
  ) = project

  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("created_at", json.string(created_at)),
    #("my_role", json.string(project_role.to_string(my_role))),
    #("members_count", json.int(members_count)),
    #("card_depth_names", json.array(card_depth_names, of: card_depth_name)),
  ])
}

fn card_depth_name(depth_name: ProjectDepthName) -> json.Json {
  let ProjectDepthName(
    depth: depth,
    singular_name: singular_name,
    plural_name: plural_name,
  ) = depth_name

  json.object([
    #("depth", json.int(depth)),
    #("singular_name", json.string(singular_name)),
    #("plural_name", json.string(plural_name)),
  ])
}

pub fn project_response(value: projects_db.ProjectRecord) -> json.Json {
  json.object([#("project", project(value))])
}

pub fn members(members: List(projects_db.ProjectMemberRecord)) -> json.Json {
  json.array(members, of: member)
}

pub fn members_response(
  values: List(projects_db.ProjectMemberRecord),
) -> json.Json {
  json.object([#("members", members(values))])
}

pub fn member(member: projects_db.ProjectMemberRecord) -> json.Json {
  let projects_db.ProjectMemberRecord(
    user_id: user_id,
    role: role,
    created_at: created_at,
    claimed_count: claimed_count,
    ..,
  ) = member

  json.object([
    #("user_id", json.int(user_id)),
    #("role", json.string(project_role.to_string(role))),
    #("created_at", json.string(created_at)),
    #("claimed_count", json.int(claimed_count)),
  ])
}

pub fn member_response(value: projects_db.ProjectMemberRecord) -> json.Json {
  json.object([#("member", member(value))])
}

pub fn role_update_result(
  result: projects_db.UpdateMemberRoleResult,
) -> json.Json {
  let projects_db.RoleUpdated(
    user_id: user_id,
    email: email,
    role: role,
    previous_role: previous_role,
  ) = result

  json.object([
    #("user_id", json.int(user_id)),
    #("email", json.string(email)),
    #("role", json.string(project_role.to_string(role))),
    #("previous_role", json.string(project_role.to_string(previous_role))),
  ])
}

pub fn role_update_response(
  value: projects_db.UpdateMemberRoleResult,
) -> json.Json {
  json.object([#("member", role_update_result(value))])
}

pub fn release_all_result(result: tasks_queries.ReleaseAllResult) -> json.Json {
  let tasks_queries.ReleaseAllResult(
    released_count: released_count,
    task_ids: task_ids,
  ) = result

  json.object([
    #("released_count", json.int(released_count)),
    #("task_ids", json.array(task_ids, json.int)),
  ])
}
