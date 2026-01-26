//// HTTP handlers for organization user management.
////
//// ## Mission
////
//// Serve organization user directory endpoints with strict authorization.
////
//// ## Responsibilities
////
//// - List users in an organization directory
//// - Update organization roles (admin only)
////
//// ## Non-responsibilities
////
//// - Persisting user data (delegated to services/org_users_db)
//// - Rendering UI (handled by client)
////
//// ## Relations
////
//// - Uses `services/org_users_db` for persistence
//// - Uses `services/projects_db` for access checks
//// - Uses `http/auth` and `http/csrf` for authentication and CSRF validation

import domain/org_role
import domain/project_role
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/org_users_db
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/sql
import wisp

/// Handle /api/org/users requests.
/// Example: handle_org_users(req, ctx)
pub fn handle_org_users(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

/// Handle /api/org/users/:user_id requests.
/// Example: handle_org_user(req, ctx, user_id)
pub fn handle_org_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_update(req, ctx, user_id)
    _ -> wisp.method_not_allowed([http.Patch])
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Patch)
  use data <- wisp.require_json(req)

  case update_org_user_role(req, ctx, user_id, data) {
    Ok(updated) -> api.ok(json.object([#("user", user_json(updated))]))
    Error(resp) -> resp
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case list_org_users(req, ctx) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn require_org_user_directory_access(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
  role: org_role.OrgRole,
) -> Result(Nil, wisp.Response) {
  case role {
    org_role.Admin -> Ok(Nil)
    _ -> require_project_manager_access(db, user_id, org_id)
  }
}

fn require_project_manager_access(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_any_project_manager_in_org(db, user_id, org_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn parse_q(query: List(#(String, String))) -> Result(String, wisp.Response) {
  case single_query_value(query, "q") {
    Ok(None) -> Ok("")
    Ok(Some(v)) -> Ok(v)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid q"))
  }
}

fn list_org_users(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(json.Json, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_org_user_directory_access(
    db,
    user.id,
    user.org_id,
    user.org_role,
  ))
  let query = wisp.get_query(req)
  use q <- result.try(parse_q(query))
  case org_users_db.list_org_users(db, user.org_id, q) {
    Ok(users) -> Ok(json.object([#("users", json.array(users, of: user_json))]))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn update_org_user_role(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
  data: dynamic.Dynamic,
) -> Result(org_users_db.OrgUser, wisp.Response) {
  use target_user_id <- result.try(parse_user_id(user_id))
  use new_role_value <- result.try(decode_org_role(data))
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(require_csrf(req))
  use new_role <- result.try(parse_org_role(new_role_value))
  let auth.Ctx(db: db, ..) = ctx
  update_org_role(db, user.org_id, target_user_id, new_role)
}

fn parse_user_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid user_id"))
  }
}

fn decode_org_role(data: dynamic.Dynamic) -> Result(String, wisp.Response) {
  let decoder = {
    use role <- decode.field("org_role", decode.string)
    decode.success(role)
  }

  case decode.run(data, decoder) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid JSON"))
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
    _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn require_org_admin_with_message(
  user: StoredUser,
  message: String,
) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ -> Error(api.error(403, "FORBIDDEN", message))
  }
}

fn require_csrf(req: wisp.Request) -> Result(Nil, wisp.Response) {
  case csrf.require_double_submit(req) {
    Ok(Nil) -> Ok(Nil)
    Error(_) ->
      Error(api.error(403, "FORBIDDEN", "CSRF token missing or invalid"))
  }
}

fn parse_org_role(value: String) -> Result(org_role.OrgRole, wisp.Response) {
  case org_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid org_role"))
  }
}

fn update_org_role(
  db: pog.Connection,
  org_id: Int,
  target_user_id: Int,
  new_role: org_role.OrgRole,
) -> Result(org_users_db.OrgUser, wisp.Response) {
  case org_users_db.update_org_role(db, org_id, target_user_id, new_role) {
    Ok(updated) -> Ok(updated)
    Error(org_users_db.InvalidRole) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid org_role"))
    Error(org_users_db.UserNotFound) ->
      Error(api.error(404, "NOT_FOUND", "User not found"))
    Error(org_users_db.CannotDemoteLastAdmin) ->
      Error(api.error(
        409,
        "CONFLICT_LAST_ORG_ADMIN",
        "Cannot demote last org admin",
      ))
    Error(org_users_db.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn single_query_value(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(String), Nil) {
  let values =
    query
    |> list.filter_map(fn(pair) {
      case pair.0 == key {
        True -> Ok(pair.1)
        False -> Error(Nil)
      }
    })

  case values {
    [] -> Ok(None)
    [value] -> Ok(Some(value))
    _ -> Error(Nil)
  }
}

fn user_json(user: org_users_db.OrgUser) -> json.Json {
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

// =============================================================================
// User Projects Handlers
// =============================================================================

/// Handle GET/POST for /api/v1/org/users/:user_id/projects.
/// Example: handle_user_projects(req, ctx, user_id)
pub fn handle_user_projects(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list_user_projects(req, ctx, user_id)
    http.Post -> handle_add_user_to_project(req, ctx, user_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle DELETE/PATCH for /api/v1/org/users/:user_id/projects/:project_id.
/// Example: handle_user_project(req, ctx, user_id, project_id)
pub fn handle_user_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Delete ->
      handle_remove_user_from_project(req, ctx, user_id, project_id)
    http.Patch -> handle_update_user_project_role(req, ctx, user_id, project_id)
    _ -> wisp.method_not_allowed([http.Delete, http.Patch])
  }
}

fn handle_list_user_projects(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
) -> wisp.Response {
  case list_user_projects(req, ctx, user_id_str) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn list_user_projects(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
) -> Result(json.Json, wisp.Response) {
  use target_user_id <- result.try(parse_user_id(user_id_str))
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin_with_message(
    user,
    "Only org admins can manage user projects",
  ))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(verify_same_org(db, target_user_id, user.org_id))
  use projects <- result.try(fetch_user_projects(db, target_user_id))

  Ok(json.object([#("projects", json.array(projects, of: project_json))]))
}

fn fetch_user_projects(
  db: pog.Connection,
  user_id: Int,
) -> Result(List(projects_db.Project), wisp.Response) {
  case projects_db.list_projects_for_user(db, user_id) {
    Ok(projects) -> Ok(projects)
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn handle_add_user_to_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case add_user_to_project(req, ctx, user_id_str, data) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn add_user_to_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  data: dynamic.Dynamic,
) -> Result(json.Json, wisp.Response) {
  use target_user_id <- result.try(parse_user_id(user_id_str))
  use #(project_id, role_value) <- result.try(decode_user_project_payload(data))
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin_with_message(
    user,
    "Only org admins can add users to projects",
  ))
  use _ <- result.try(require_csrf(req))
  let auth.Ctx(db: db, ..) = ctx
  use role <- result.try(parse_project_role(role_value))
  use member <- result.try(add_project_member(
    db,
    project_id,
    target_user_id,
    role,
  ))

  let project_name = get_project_name(db, project_id)
  Ok(
    json.object([
      #("project", project_member_json(project_id, project_name, member)),
    ]),
  )
}

fn decode_user_project_payload(
  data: dynamic.Dynamic,
) -> Result(#(Int, String), wisp.Response) {
  let decoder = {
    use project_id <- decode.field("project_id", decode.int)
    use role <- decode.optional_field("role", "member", decode.string)
    decode.success(#(project_id, role))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(422, "VALIDATION_ERROR", "Invalid JSON: project_id required")
  })
}

fn parse_project_role(
  value: String,
) -> Result(project_role.ProjectRole, wisp.Response) {
  case project_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid role"))
  }
}

fn add_project_member(
  db: pog.Connection,
  project_id: Int,
  target_user_id: Int,
  role: project_role.ProjectRole,
) -> Result(projects_db.ProjectMember, wisp.Response) {
  case projects_db.add_member(db, project_id, target_user_id, role) {
    Ok(member) -> Ok(member)
    Error(projects_db.ProjectNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Project not found"))
    Error(projects_db.TargetUserNotFound) ->
      Error(api.error(404, "NOT_FOUND", "User not found"))
    Error(projects_db.TargetUserWrongOrg) ->
      Error(api.error(403, "FORBIDDEN", "User not in same organization"))
    Error(projects_db.AlreadyMember) ->
      Error(api.error(
        409,
        "CONFLICT",
        "User is already a member of this project",
      ))
    Error(projects_db.InvalidRole) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid role"))
    Error(projects_db.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn handle_remove_user_from_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  project_id_str: String,
) -> wisp.Response {
  case remove_user_from_project(req, ctx, user_id_str, project_id_str) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn remove_user_from_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  project_id_str: String,
) -> Result(json.Json, wisp.Response) {
  use #(target_user_id, project_id) <- result.try(parse_user_project_ids(
    user_id_str,
    project_id_str,
  ))
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin_with_message(
    user,
    "Only org admins can remove users from projects",
  ))
  use _ <- result.try(require_csrf(req))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(remove_project_member(db, project_id, target_user_id))

  Ok(json.object([]))
}

fn remove_project_member(
  db: pog.Connection,
  project_id: Int,
  target_user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.remove_member(db, project_id, target_user_id) {
    Ok(Nil) -> Ok(Nil)
    Error(projects_db.MembershipNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Membership not found"))
    Error(projects_db.CannotRemoveLastManager) ->
      Error(api.error(409, "CONFLICT", "Cannot remove last project admin"))
    Error(projects_db.RemoveDbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn handle_update_user_project_role(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  project_id_str: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case update_user_project_role(req, ctx, user_id_str, project_id_str, data) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn update_user_project_role(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  project_id_str: String,
  data: dynamic.Dynamic,
) -> Result(json.Json, wisp.Response) {
  use #(target_user_id, project_id) <- result.try(parse_user_project_ids(
    user_id_str,
    project_id_str,
  ))
  use role_value <- result.try(decode_role_value(data))
  use user <- result.try(require_current_user(req, ctx))
  use _ <- result.try(require_org_admin_with_message(
    user,
    "Only org admins can change user project roles",
  ))
  use _ <- result.try(require_csrf(req))
  let auth.Ctx(db: db, ..) = ctx
  use new_role <- result.try(parse_project_role(role_value))
  use update_result <- result.try(update_project_member_role(
    db,
    project_id,
    target_user_id,
    new_role,
  ))

  let projects_db.RoleUpdated(
    user_id: _,
    email: _,
    role: role,
    previous_role: previous_role,
  ) = update_result

  let project_name = get_project_name(db, project_id)
  Ok(
    json.object([
      #(
        "project",
        json.object([
          #("id", json.int(project_id)),
          #("name", json.string(project_name)),
          #("role", json.string(project_role.to_string(role))),
          #("previous_role", json.string(project_role.to_string(previous_role))),
        ]),
      ),
    ]),
  )
}

fn decode_role_value(data: dynamic.Dynamic) -> Result(String, wisp.Response) {
  let decoder = {
    use role <- decode.field("role", decode.string)
    decode.success(role)
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(422, "VALIDATION_ERROR", "Invalid JSON: role required")
  })
}

fn update_project_member_role(
  db: pog.Connection,
  project_id: Int,
  target_user_id: Int,
  new_role: project_role.ProjectRole,
) -> Result(projects_db.UpdateMemberRoleResult, wisp.Response) {
  case
    projects_db.update_member_role(db, project_id, target_user_id, new_role)
  {
    Ok(result) -> Ok(result)
    Error(projects_db.UpdateMemberNotFound) ->
      Error(api.error(404, "NOT_FOUND", "User is not a member of this project"))
    Error(projects_db.UpdateLastManager) ->
      Error(api.error(
        422,
        "LAST_MANAGER",
        "Cannot demote the last project manager",
      ))
    Error(projects_db.UpdateInvalidRole) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid role"))
    Error(projects_db.UpdateDbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn parse_user_project_ids(
  user_id_str: String,
  project_id_str: String,
) -> Result(#(Int, Int), wisp.Response) {
  use user_id <- result.try(parse_user_id(user_id_str))
  use project_id <- result.try(parse_project_id(project_id_str))
  Ok(#(user_id, project_id))
}

fn parse_project_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid project_id"))
  }
}

fn verify_same_org(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
) -> Result(Nil, wisp.Response) {
  case sql.users_org_id(db, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) if row.org_id == org_id -> Ok(Nil)
    Ok(pog.Returned(rows: [_, ..], ..)) ->
      Error(api.error(404, "NOT_FOUND", "User not found"))
    Ok(pog.Returned(rows: [], ..)) ->
      Error(api.error(404, "NOT_FOUND", "User not found"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn project_json(project: projects_db.Project) -> json.Json {
  json.object([
    #("id", json.int(project.id)),
    #("name", json.string(project.name)),
    #("role", json.string(project_role.to_string(project.my_role))),
  ])
}

fn project_member_json(
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

/// Fetch project name by ID.
fn get_project_name(db: pog.Connection, project_id: Int) -> String {
  case sql.engine_get_project_name(db, project_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> row.name
    _ -> ""
  }
}
