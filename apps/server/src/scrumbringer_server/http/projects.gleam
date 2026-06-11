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
//// - List, add, and remove project members (org admin or project manager)
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
import gleam/http
import gleam/list
import gleam/option.{Some}
import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization as http_authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/http/projects/payloads as project_payloads
import scrumbringer_server/http/projects/presenters as project_presenters
import scrumbringer_server/http/service_error_response
import scrumbringer_server/persistence/tasks/queries as tasks_queries
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

/// Handle /api/projects/:id/members/:user_id/release-all-tasks requests.
/// Example: handle_member_release_all(req, ctx, project_id, user_id)
pub fn handle_member_release_all(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> wisp.Response {
  case req.method {
    http.Post -> handle_member_release_all_post(req, ctx, project_id, user_id)
    _ -> wisp.method_not_allowed([http.Post])
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
  case require_project_update_access(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(project_id) ->
      json_payload.with_response(req, decode_project_name, fn(payload) {
        case update_project(ctx, project_id, payload) {
          Ok(project) -> api.ok(project_presenters.project_response(project))
          Error(resp) -> resp
        }
      })
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
  case require_member_role_update_access(req, ctx, project_id, user_id) {
    Error(resp) -> resp
    Ok(#(project_id, target_user_id)) ->
      json_payload.with_response(req, decode_role_value, fn(payload) {
        case update_member_role(ctx, project_id, target_user_id, payload) {
          Ok(result) -> api.ok(project_presenters.role_update_response(result))
          Error(resp) -> resp
        }
      })
  }
}

fn handle_member_release_all_post(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> wisp.Response {
  case release_all_tasks(req, ctx, project_id, user_id) {
    Ok(payload) -> api.ok(payload)
    Error(resp) -> resp
  }
}

fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case require_org_admin_write(req, ctx) {
    Error(resp) -> resp
    Ok(user) ->
      json_payload.with_response(req, decode_project_name, fn(payload) {
        case create_project(ctx, user, payload) {
          Ok(project) -> api.ok(project_presenters.project_response(project))
          Error(resp) -> resp
        }
      })
  }
}

fn create_project(
  ctx: auth.Ctx,
  user: StoredUser,
  payload: project_payloads.ProjectNamePayload,
) -> Result(projects_db.Project, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.create_project(db, user.org_id, user.id, payload.name) {
    Ok(project) -> Ok(project)
    Error(_) -> Error(database_error_response())
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
  case require_add_member_access(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(project_id) ->
      json_payload.with_response(req, decode_member_payload, fn(payload) {
        case add_member(ctx, project_id, payload) {
          Ok(member) -> api.ok(project_presenters.member_response(member))
          Error(resp) -> resp
        }
      })
  }
}

fn require_project_update_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(Int, wisp.Response) {
  use _user <- result.try(require_org_admin_write(req, ctx))
  api.parse_id(project_id)
}

fn update_project(
  ctx: auth.Ctx,
  project_id: Int,
  payload: project_payloads.ProjectNamePayload,
) -> Result(projects_db.Project, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.update_project(db, project_id, payload.name) {
    Ok(project) -> Ok(project)
    Error(error) -> Error(update_project_error_response(error))
  }
}

fn delete_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(Nil, wisp.Response) {
  use _user <- result.try(require_org_admin_write(req, ctx))
  use project_id <- result.try(api.parse_id(project_id))
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.delete_project(db, project_id) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(delete_project_error_response(error))
  }
}

fn remove_member(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> Result(Nil, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(api.parse_id(project_id))
  use target_user_id <- result.try(api.parse_id(user_id))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_members_management_access(db, user, project_id))
  case projects_db.remove_member(db, project_id, target_user_id) {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(remove_member_error_response(error))
  }
}

fn update_member_role(
  ctx: auth.Ctx,
  project_id: Int,
  target_user_id: Int,
  payload: project_payloads.RolePayload,
) -> Result(projects_db.UpdateMemberRoleResult, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  case
    projects_db.update_member_role(db, project_id, target_user_id, payload.role)
  {
    Ok(result) -> Ok(result)
    Error(error) -> Error(update_member_role_error_response(error))
  }
}

fn list_projects(req: wisp.Request, ctx: auth.Ctx) {
  use principal <- result.try(auth.require_principal_response(req, ctx))
  let auth.Principal(user: user, source: source) = principal
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.list_projects_for_user(db, user.id) {
    Ok(projects) ->
      Ok(
        project_presenters.projects_response(filter_projects_for_source(
          projects,
          source,
        )),
      )
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn filter_projects_for_source(
  projects: List(projects_db.Project),
  source: auth.AuthSource,
) -> List(projects_db.Project) {
  case source {
    auth.WebSession -> projects
    auth.ApiToken(token) ->
      case token.project_id {
        Some(project_id) ->
          list.filter(projects, fn(project) { project.id == project_id })
        _ -> projects
      }
  }
}

fn list_members(req: wisp.Request, ctx: auth.Ctx, project_id: String) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use project_id <- result.try(api.parse_id(project_id))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_members_management_access(db, user, project_id))
  case projects_db.list_members(db, project_id) {
    Ok(members) -> Ok(project_presenters.members_response(members))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn release_all_tasks(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(api.parse_id(project_id))
  use target_user_id <- result.try(api.parse_id(user_id))
  use _ <- result.try(require_target_not_current_user(user.id, target_user_id))

  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_exists(db, project_id))
  use _ <- result.try(require_user_exists(db, target_user_id))
  use _ <- result.try(require_members_management_access(db, user, project_id))
  use _ <- result.try(require_project_member_exists(
    db,
    project_id,
    target_user_id,
  ))

  case
    tasks_queries.release_all_tasks_for_user(
      db,
      user.org_id,
      project_id,
      target_user_id,
      user.id,
    )
  {
    Ok(result) -> Ok(project_presenters.release_all_result(result))
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn add_member(
  ctx: auth.Ctx,
  project_id: Int,
  payload: project_payloads.MemberPayload,
) -> Result(projects_db.ProjectMember, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  case projects_db.add_member(db, project_id, payload.user_id, payload.role) {
    Ok(member) -> Ok(member)
    Error(error) -> Error(add_member_error_response(error))
  }
}

fn require_org_admin(user: StoredUser) -> Result(Nil, wisp.Response) {
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ ->
      Error(api.error(403, "FORBIDDEN", "Only org admins can manage projects"))
  }
}

fn require_org_admin_write(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(require_org_admin(user))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(user)
}

fn require_add_member_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(Int, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use _ <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(api.parse_id(project_id))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_members_management_access(db, user, project_id))
  Ok(project_id)
}

fn require_member_role_update_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> Result(#(Int, Int), wisp.Response) {
  use _user <- result.try(require_org_admin_write(req, ctx))
  use project_id <- result.try(api.parse_id(project_id))
  use target_user_id <- result.try(api.parse_id(user_id))
  Ok(#(project_id, target_user_id))
}

fn require_members_management_access(
  db,
  user: StoredUser,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  http_authorization.require_project_manager_with_org_bypass(
    db,
    user,
    project_id,
  )
}

fn require_target_not_current_user(
  current_user_id: Int,
  target_user_id: Int,
) -> Result(Nil, wisp.Response) {
  case target_user_id == current_user_id {
    True -> Error(api.error(400, "SELF_RELEASE", "Cannot release own tasks"))
    False -> Ok(Nil)
  }
}

fn require_project_exists(db, project_id: Int) -> Result(Nil, wisp.Response) {
  case projects_db.project_exists(db, project_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(project_not_found_response())
    Error(_) -> Error(database_error_response())
  }
}

fn require_user_exists(db, user_id: Int) -> Result(Nil, wisp.Response) {
  case projects_db.user_exists(db, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(user_not_found_response())
    Error(_) -> Error(database_error_response())
  }
}

fn require_project_member_exists(
  db,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_member(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(membership_not_found_response())
    Error(_) -> Error(database_error_response())
  }
}

fn update_project_error_response(
  error: projects_db.UpdateProjectError,
) -> wisp.Response {
  case error {
    projects_db.UpdateProjectNotFound -> project_not_found_response()
    projects_db.UpdateProjectDbError(_) -> database_error_response()
  }
}

fn delete_project_error_response(
  error: projects_db.DeleteProjectError,
) -> wisp.Response {
  case error {
    projects_db.DeleteProjectNotFound -> project_not_found_response()
    projects_db.DeleteProjectDbError(_) -> database_error_response()
  }
}

fn remove_member_error_response(
  error: projects_db.RemoveMemberError,
) -> wisp.Response {
  case error {
    projects_db.MembershipNotFound -> membership_not_found_response()
    projects_db.CannotRemoveLastManager ->
      api.error(422, "VALIDATION_ERROR", "Cannot remove last project manager")
    projects_db.RemoveDbError(_) -> database_error_response()
  }
}

fn update_member_role_error_response(
  error: projects_db.UpdateMemberRoleError,
) -> wisp.Response {
  case error {
    projects_db.UpdateMemberNotFound -> membership_not_found_response()
    projects_db.UpdateLastManager ->
      api.error(422, "VALIDATION_ERROR", "Cannot demote last project manager")
    projects_db.UpdateDbError(_) -> database_error_response()
  }
}

fn add_member_error_response(error: projects_db.AddMemberError) -> wisp.Response {
  case error {
    projects_db.ProjectNotFound -> project_not_found_response()
    projects_db.TargetUserNotFound -> user_not_found_response()
    projects_db.TargetUserWrongOrg ->
      api.error(422, "VALIDATION_ERROR", "User must be in same organization")
    projects_db.AlreadyMember ->
      api.error(422, "VALIDATION_ERROR", "User is already a member")
    projects_db.DbError(_) -> database_error_response()
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

fn decode_project_name(
  data,
) -> Result(project_payloads.ProjectNamePayload, wisp.Response) {
  case project_payloads.decode_project_name(data) {
    Ok(payload) -> Ok(payload)
    Error(_) -> Error(api.error(400, "INVALID_BODY", "Invalid request body"))
  }
}

fn decode_member_payload(
  data,
) -> Result(project_payloads.MemberPayload, wisp.Response) {
  case project_payloads.decode_member(data) {
    Ok(payload) -> Ok(payload)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}

fn decode_role_value(
  data,
) -> Result(project_payloads.RolePayload, wisp.Response) {
  case project_payloads.decode_role(data) {
    Ok(payload) -> Ok(payload)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}
