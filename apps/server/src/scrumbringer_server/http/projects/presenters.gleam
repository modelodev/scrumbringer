//// JSON presenters for project endpoints.

import domain/project.{type ProjectDepthName, ProjectDepthName}
import domain/project_role
import gleam/json
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/projects_db

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
    healthy_pool_limit: healthy_pool_limit,
    ..,
  ) = project

  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("created_at", json.string(created_at)),
    #("my_role", json.string(project_role.to_string(my_role))),
    #("members_count", json.int(members_count)),
    #("card_depth_names", json.array(card_depth_names, of: card_depth_name)),
    #("healthy_pool_limit", json.int(healthy_pool_limit)),
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

pub fn depth_reduction_impact_response(
  impact: projects_db.DepthReductionImpact,
) -> json.Json {
  let projects_db.DepthReductionImpact(
    affected_cards_count: affected_cards_count,
    available_tasks_count: available_tasks_count,
    claimed_tasks_count: claimed_tasks_count,
    affected_cards: affected_cards,
  ) = impact

  json.object([
    #("affected_cards_count", json.int(affected_cards_count)),
    #("available_tasks_count", json.int(available_tasks_count)),
    #("claimed_tasks_count", json.int(claimed_tasks_count)),
    #("blocked", json.bool(claimed_tasks_count > 0)),
    #(
      "affected_cards",
      json.array(affected_cards, of: depth_reduction_affected_card),
    ),
  ])
}

fn depth_reduction_affected_card(
  affected_card: projects_db.DepthReductionAffectedCard,
) -> json.Json {
  let projects_db.DepthReductionAffectedCard(id: id, title: title, depth: depth) =
    affected_card

  json.object([
    #("id", json.int(id)),
    #("title", json.string(title)),
    #("depth", json.int(depth)),
  ])
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

fn role_update_result(result: projects_db.UpdateMemberRoleResult) -> json.Json {
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
