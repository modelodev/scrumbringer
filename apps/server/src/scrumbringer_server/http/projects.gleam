//// HTTP handlers for project management.
////
//// ## Mission
////
//// Provides HTTP endpoints for CRUD operations on projects and project members.
////
//// ## Responsibilities
////
//// - List projects for authenticated user
//// - Create projects (org admin only)
//// - List, add, and remove project members (project admin only)
////
//// ## Non-responsibilities
////
//// - Database operations (see `services/projects_db.gleam`)
//// - Authentication (see `http/auth.gleam`)
////
//// ## Relations
////
//// - Uses `services/projects_db` for persistence
//// - Uses `http/auth` and `http/csrf` for auth and CSRF validation

import domain/org_role
import domain/project_role
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

/// Handle /api/projects requests.
/// Example: handle_projects(req, ctx)
pub fn handle_projects(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    http.Post -> handle_create(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle /api/projects/:id/members requests.
/// Example: handle_members(req, ctx, project_id)
pub fn handle_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_members_list(req, ctx, project_id)
    http.Post -> handle_members_add(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle /api/projects/:id/members/:user_id requests.
/// Example: handle_member(req, ctx, project_id, user_id)
pub fn handle_member(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> wisp.Response {
  case req.method {
    http.Delete -> handle_member_delete(req, ctx, project_id, user_id)
    http.Patch -> handle_member_role_update(req, ctx, project_id, user_id)
    _ -> wisp.method_not_allowed([http.Delete, http.Patch])
  }
}

/// Handle /api/projects/:id requests.
/// Example: handle_project(req, ctx, project_id)
pub fn handle_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_project_update(req, ctx, project_id)
    http.Delete -> handle_project_delete(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

fn handle_project_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  case update_project(req, ctx, project_id, data) {
    Ok(project) -> api.ok(json.object([#("project", project_json(project))]))
    Error(resp) -> resp
  }
}

fn handle_project_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case delete_project(req, ctx, project_id) {
    Ok(Nil) -> api.no_content()
    Error(resp) -> resp
  }
}

fn handle_member_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> wisp.Response {
  case remove_member(req, ctx, project_id, user_id) {
    Ok(Nil) -> api.no_content()
    Error(resp) -> resp
  }
}

fn handle_member_role_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  case update_member_role(req, ctx, project_id, user_id, data) {
    Ok(result) ->
      api.ok(json.object([#("member", role_update_result_json(result))]))
    Error(resp) -> resp
  }
}

fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use data <- wisp.require_json(req)
  case create_project(req, ctx, data) {
    Ok(project) -> api.ok(json.object([#("project", project_json(project))]))
    Error(resp) -> resp
  }
}

fn create_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  data: dynamic.Dynamic,
) -> Result(projects_db.Project, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(csrf.require_csrf(req))
  use name <- result.try(decode_project_name(data))
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.create_project(db, user.org_id, user.id, name) {
    Ok(project) -> Ok(project)
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case list_projects(req, ctx) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn handle_members_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case list_members(req, ctx, project_id) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn handle_members_add(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  case add_member(req, ctx, project_id, data) {
    Ok(member) -> api.ok(json.object([#("member", member_json(member))]))
    Error(resp) -> resp
  }
}

fn update_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  data: dynamic.Dynamic,
) -> Result(projects_db.Project, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(parse_project_id(project_id))
  use name <- result.try(decode_project_name(data))
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.update_project(db, project_id, name) {
    Ok(project) -> Ok(project)
    Error(projects_db.UpdateProjectNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Project not found"))
    Error(projects_db.UpdateProjectDbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn delete_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(Nil, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(parse_project_id(project_id))
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.delete_project(db, project_id) {
    Ok(_) -> Ok(Nil)
    Error(projects_db.DeleteProjectNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Project not found"))
    Error(projects_db.DeleteProjectDbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn remove_member(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> Result(Nil, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(parse_project_id(project_id))
  use target_user_id <- result.try(parse_user_id(user_id))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_admin(db, project_id, user.id))
  case projects_db.remove_member(db, project_id, target_user_id) {
    Ok(Nil) -> Ok(Nil)
    Error(projects_db.MembershipNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Membership not found"))
    Error(projects_db.CannotRemoveLastManager) ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Cannot remove last project admin",
      ))
    Error(projects_db.RemoveDbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn update_member_role(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
  data: dynamic.Dynamic,
) -> Result(projects_db.UpdateMemberRoleResult, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(parse_project_id(project_id))
  use target_user_id <- result.try(parse_user_id(user_id))
  use role_value <- result.try(decode_role_value(data))
  use new_role <- result.try(parse_project_role(role_value))
  let auth.Ctx(db: db, ..) = ctx
  case
    projects_db.update_member_role(db, project_id, target_user_id, new_role)
  {
    Ok(result) -> Ok(result)
    Error(projects_db.UpdateMemberNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Membership not found"))
    Error(projects_db.UpdateLastManager) ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Cannot demote last project manager",
      ))
    Error(projects_db.UpdateInvalidRole) ->
      Error(api.error(400, "VALIDATION_ERROR", "Invalid role"))
    Error(projects_db.UpdateDbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn list_projects(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(json.Json, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.list_projects_for_user(db, user.id) {
    Ok(projects) ->
      Ok(
        json.object([
          #("projects", projects |> list_to_json(fn(p) { project_json(p) })),
        ]),
      )
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn list_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(json.Json, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use project_id <- result.try(parse_project_id(project_id))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_admin(db, project_id, user.id))
  case projects_db.list_members(db, project_id) {
    Ok(members) ->
      Ok(
        json.object([
          #("members", members |> list_to_json(fn(m) { member_json(m) })),
        ]),
      )
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn add_member(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  data: dynamic.Dynamic,
) -> Result(projects_db.ProjectMember, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(parse_project_id(project_id))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_admin(db, project_id, user.id))
  use #(target_user_id, role_value) <- result.try(decode_member_payload(data))
  use role <- result.try(parse_project_role(role_value))
  case projects_db.add_member(db, project_id, target_user_id, role) {
    Ok(member) -> Ok(member)
    Error(projects_db.ProjectNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Project not found"))
    Error(projects_db.TargetUserNotFound) ->
      Error(api.error(404, "NOT_FOUND", "User not found"))
    Error(projects_db.TargetUserWrongOrg) ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "User must be in same organization",
      ))
    Error(projects_db.AlreadyMember) ->
      Error(api.error(422, "VALIDATION_ERROR", "User is already a member"))
    Error(projects_db.InvalidRole) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid role"))
    Error(projects_db.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn require_current_user(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  case auth.require_current_user(req, ctx) {
    Ok(user) -> Ok(user)
    Error(_) ->
      Error(api.error(401, "AUTH_REQUIRED", "Authentication required"))
  }
}

fn require_org_admin(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ ->
      Error(api.error(403, "FORBIDDEN", "Only org admins can manage projects"))
  }
}


fn parse_project_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn parse_user_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn decode_project_name(data: dynamic.Dynamic) -> Result(String, wisp.Response) {
  let decoder = decode.field("name", decode.string, decode.success)
  case decode.run(data, decoder) {
    Ok(name) -> Ok(name)
    Error(_) -> Error(api.error(400, "INVALID_BODY", "Invalid request body"))
  }
}

fn decode_member_payload(
  data: dynamic.Dynamic,
) -> Result(#(Int, String), wisp.Response) {
  let decoder = {
    use user_id <- decode.field("user_id", decode.int)
    use role <- decode.field("role", decode.string)
    decode.success(#(user_id, role))
  }
  case decode.run(data, decoder) {
    Ok(payload) -> Ok(payload)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}

fn decode_role_value(data: dynamic.Dynamic) -> Result(String, wisp.Response) {
  let decoder = {
    use role <- decode.field("role", decode.string)
    decode.success(role)
  }
  case decode.run(data, decoder) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}

fn parse_project_role(
  value: String,
) -> Result(project_role.ProjectRole, wisp.Response) {
  case project_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid role"))
  }
}

fn require_project_admin(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_manager(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn list_to_json(values: List(a), f: fn(a) -> json.Json) -> json.Json {
  json.array(values, of: f)
}

fn project_json(project: projects_db.Project) -> json.Json {
  let projects_db.Project(
    id: id,
    org_id: org_id,
    name: name,
    created_at: created_at,
    my_role: my_role,
    members_count: members_count,
  ) = project

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("name", json.string(name)),
    #("created_at", json.string(created_at)),
    #("my_role", json.string(project_role.to_string(my_role))),
    #("members_count", json.int(members_count)),
  ])
}

fn member_json(member: projects_db.ProjectMember) -> json.Json {
  let projects_db.ProjectMember(
    project_id: project_id,
    user_id: user_id,
    role: role,
    created_at: created_at,
  ) = member

  json.object([
    #("project_id", json.int(project_id)),
    #("user_id", json.int(user_id)),
    #("role", json.string(project_role.to_string(role))),
    #("created_at", json.string(created_at)),
  ])
}

fn role_update_result_json(
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
