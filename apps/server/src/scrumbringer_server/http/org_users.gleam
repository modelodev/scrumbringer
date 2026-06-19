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
//// - Persisting user data (delegated to use_case/org_users_db)
//// - Rendering UI (handled by client)
////
//// ## Relations
////
//// - Uses `use_case/org_users_db` for repository
//// - Uses `use_case/projects_db` for access checks
//// - Uses `http/auth` and `http/csrf` for authentication and CSRF validation

import domain/org_role
import domain/project_role
import gleam/http
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/http/org_users/payloads as org_user_payloads
import scrumbringer_server/http/org_users/presenters as org_user_presenters
import scrumbringer_server/http/query as query_params
import scrumbringer_server/sql
import scrumbringer_server/use_case/org_users_db
import scrumbringer_server/use_case/projects_db
import scrumbringer_server/use_case/store_state.{type StoredUser}
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
    http.Delete -> handle_delete(req, ctx, user_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Patch)

  case require_org_role_update_access(req, ctx, user_id) {
    Error(resp) -> resp
    Ok(#(user, target_user_id)) ->
      json_payload.with_response(req, decode_org_role, fn(payload) {
        case update_org_user_role(ctx, user, target_user_id, payload) {
          Ok(updated) -> api.ok(org_user_presenters.user_response(updated))
          Error(resp) -> resp
        }
      })
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Delete)

  case delete_org_user(req, ctx, user_id) {
    Ok(_) -> api.no_content()
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
  case query_params.single_value(query, "q") {
    Ok(None) -> Ok("")
    Ok(Some(v)) -> Ok(v)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid q"))
  }
}

fn list_org_users(req: wisp.Request, ctx: auth.Ctx) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
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
    Ok(users) -> Ok(org_user_presenters.users_response(users))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn update_org_user_role(
  ctx: auth.Ctx,
  user: StoredUser,
  target_user_id: Int,
  payload: org_user_payloads.OrgRolePayload,
) -> Result(org_users_db.OrgUser, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  update_org_role(db, user.org_id, target_user_id, payload.org_role)
}

fn require_org_role_update_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> Result(#(StoredUser, Int), wisp.Response) {
  use target_user_id <- result.try(parse_user_id(user_id))
  use user <- result.try(require_org_admin_write(req, ctx, "Forbidden"))
  Ok(#(user, target_user_id))
}

fn parse_user_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid user_id"))
  }
}

fn decode_org_role(
  data,
) -> Result(org_user_payloads.OrgRolePayload, wisp.Response) {
  case org_user_payloads.decode_org_role(data) {
    Ok(payload) -> Ok(payload)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid JSON"))
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

fn require_org_admin_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  message: String,
) -> Result(StoredUser, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(require_org_admin_with_message(user, message))
  Ok(user)
}

fn require_org_admin_write(
  req: wisp.Request,
  ctx: auth.Ctx,
  message: String,
) -> Result(StoredUser, wisp.Response) {
  use user <- result.try(require_org_admin_access(req, ctx, message))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(user)
}

fn update_org_role(
  db: pog.Connection,
  org_id: Int,
  target_user_id: Int,
  new_role: org_role.OrgRole,
) -> Result(org_users_db.OrgUser, wisp.Response) {
  case org_users_db.update_org_role(db, org_id, target_user_id, new_role) {
    Ok(updated) -> Ok(updated)
    Error(error) -> Error(update_org_role_error_response(error))
  }
}

fn delete_org_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> Result(Nil, wisp.Response) {
  use target_user_id <- result.try(parse_user_id(user_id))
  use user <- result.try(require_org_admin_write(req, ctx, "Forbidden"))
  use _ <- result.try(require_not_self_delete(user.id, target_user_id))

  let auth.Ctx(db: db, ..) = ctx
  case org_users_db.delete_org_user(db, user.org_id, target_user_id) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(delete_org_user_error_response(error))
  }
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

fn list_user_projects(req: wisp.Request, ctx: auth.Ctx, user_id_str: String) {
  use target_user_id <- result.try(parse_user_id(user_id_str))
  use user <- result.try(require_org_admin_access(
    req,
    ctx,
    "Only org admins can manage user projects",
  ))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(verify_same_org(db, target_user_id, user.org_id))
  use projects <- result.try(fetch_user_projects(db, target_user_id))

  Ok(org_user_presenters.user_projects_response(projects))
}

fn fetch_user_projects(
  db: pog.Connection,
  user_id: Int,
) -> Result(List(projects_db.ProjectRecord), wisp.Response) {
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
  case require_add_user_to_project_access(req, ctx, user_id_str) {
    Error(resp) -> resp
    Ok(target_user_id) ->
      json_payload.with_response(req, decode_user_project_payload, fn(payload) {
        case add_user_to_project(ctx, target_user_id, payload) {
          Ok(response_payload) -> api.ok(response_payload)
          Error(resp) -> resp
        }
      })
  }
}

fn add_user_to_project(
  ctx: auth.Ctx,
  target_user_id: Int,
  payload: org_user_payloads.UserProjectPayload,
) {
  let auth.Ctx(db: db, ..) = ctx
  use member <- result.try(add_project_member(
    db,
    payload.project_id,
    target_user_id,
    payload.role,
  ))

  let project_name = get_project_name(db, payload.project_id)
  Ok(org_user_presenters.project_member_response(
    payload.project_id,
    project_name,
    member,
  ))
}

fn require_add_user_to_project_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
) -> Result(Int, wisp.Response) {
  use target_user_id <- result.try(parse_user_id(user_id_str))
  use _user <- result.try(require_org_admin_write(
    req,
    ctx,
    "Only org admins can add users to projects",
  ))
  Ok(target_user_id)
}

fn decode_user_project_payload(
  data,
) -> Result(org_user_payloads.UserProjectPayload, wisp.Response) {
  org_user_payloads.decode_user_project(data)
  |> result.map_error(fn(_) {
    api.error(422, "VALIDATION_ERROR", "Invalid JSON: project_id required")
  })
}

fn add_project_member(
  db: pog.Connection,
  project_id: Int,
  target_user_id: Int,
  role: project_role.ProjectRole,
) -> Result(projects_db.ProjectMemberRecord, wisp.Response) {
  case projects_db.add_member(db, project_id, target_user_id, role) {
    Ok(member) -> Ok(member)
    Error(error) -> Error(add_project_member_error_response(error))
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
) {
  use #(target_user_id, project_id) <- result.try(parse_user_project_ids(
    user_id_str,
    project_id_str,
  ))
  use _user <- result.try(require_org_admin_write(
    req,
    ctx,
    "Only org admins can remove users from projects",
  ))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(remove_project_member(db, project_id, target_user_id))

  Ok(org_user_presenters.empty_response())
}

fn remove_project_member(
  db: pog.Connection,
  project_id: Int,
  target_user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.remove_member(db, project_id, target_user_id) {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(remove_project_member_error_response(error))
  }
}

fn handle_update_user_project_role(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  project_id_str: String,
) -> wisp.Response {
  case
    require_update_user_project_role_access(
      req,
      ctx,
      user_id_str,
      project_id_str,
    )
  {
    Error(resp) -> resp
    Ok(#(target_user_id, project_id)) ->
      json_payload.with_response(req, decode_role_value, fn(payload) {
        case
          update_user_project_role(ctx, target_user_id, project_id, payload)
        {
          Ok(response_payload) -> api.ok(response_payload)
          Error(resp) -> resp
        }
      })
  }
}

fn update_user_project_role(
  ctx: auth.Ctx,
  target_user_id: Int,
  project_id: Int,
  role_value: org_user_payloads.RolePayload,
) {
  let auth.Ctx(db: db, ..) = ctx
  use update_result <- result.try(update_project_member_role(
    db,
    project_id,
    target_user_id,
    role_value.role,
  ))

  let project_name = get_project_name(db, project_id)
  Ok(org_user_presenters.project_role_update_response(
    project_id,
    project_name,
    update_result,
  ))
}

fn require_update_user_project_role_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  project_id_str: String,
) -> Result(#(Int, Int), wisp.Response) {
  use ids <- result.try(parse_user_project_ids(user_id_str, project_id_str))
  use _user <- result.try(require_org_admin_write(
    req,
    ctx,
    "Only org admins can change user project roles",
  ))
  Ok(ids)
}

fn decode_role_value(
  data,
) -> Result(org_user_payloads.RolePayload, wisp.Response) {
  org_user_payloads.decode_role(data)
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
    Error(error) -> Error(update_project_member_role_error_response(error))
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

fn require_not_self_delete(
  current_user_id: Int,
  target_user_id: Int,
) -> Result(Nil, wisp.Response) {
  case current_user_id == target_user_id {
    True -> Error(api.error(409, "CONFLICT_SELF_DELETE", "Cannot delete self"))
    False -> Ok(Nil)
  }
}

fn update_org_role_error_response(
  error: org_users_db.UpdateOrgRoleError,
) -> wisp.Response {
  case error {
    org_users_db.UpdateUserNotFound -> user_not_found_response()
    org_users_db.UpdateCannotDemoteLastAdmin ->
      api.error(409, "CONFLICT_LAST_ORG_ADMIN", "Cannot demote last org admin")
    org_users_db.UpdateDbError(_) -> database_error_response()
  }
}

fn delete_org_user_error_response(
  error: org_users_db.DeleteOrgUserError,
) -> wisp.Response {
  case error {
    org_users_db.DeleteUserNotFound -> user_not_found_response()
    org_users_db.DeleteLastAdmin ->
      api.error(409, "CONFLICT_LAST_ORG_ADMIN", "Cannot delete last org admin")
    org_users_db.DeleteDbError(_) -> database_error_response()
  }
}

fn add_project_member_error_response(
  error: projects_db.AddMemberError,
) -> wisp.Response {
  case error {
    projects_db.ProjectNotFound -> project_not_found_response()
    projects_db.TargetUserNotFound -> user_not_found_response()
    projects_db.TargetUserWrongOrg ->
      api.error(403, "FORBIDDEN", "User not in same organization")
    projects_db.AlreadyMember ->
      api.error(409, "CONFLICT", "User is already a member of this project")
    projects_db.DbError(_) -> database_error_response()
  }
}

fn remove_project_member_error_response(
  error: projects_db.RemoveMemberError,
) -> wisp.Response {
  case error {
    projects_db.MembershipNotFound -> membership_not_found_response()
    projects_db.CannotRemoveLastManager ->
      api.error(409, "CONFLICT", "Cannot remove last project admin")
    projects_db.RemoveDbError(_) -> database_error_response()
  }
}

fn update_project_member_role_error_response(
  error: projects_db.UpdateMemberRoleError,
) -> wisp.Response {
  case error {
    projects_db.UpdateMemberNotFound ->
      api.error(404, "NOT_FOUND", "User is not a member of this project")
    projects_db.UpdateLastManager ->
      api.error(422, "LAST_MANAGER", "Cannot demote the last project manager")
    projects_db.UpdateDbError(_) -> database_error_response()
  }
}

fn project_not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Project not found")
}

fn user_not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "User not found")
}

fn membership_not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Membership not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
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

/// Fetch project name by ID.
fn get_project_name(db: pog.Connection, project_id: Int) -> String {
  case sql.engine_get_project_name(db, project_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> row.name
    _ -> ""
  }
}
