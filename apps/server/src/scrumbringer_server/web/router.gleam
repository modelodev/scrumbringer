//// HTTP Router
////
//// Centralized routing for the ScrumBringer API. Defines all route patterns
//// and dispatches requests to specialized HTTP handlers.
////
//// This module keeps `scrumbringer_server.gleam` focused on bootstrap concerns
//// (database pool, middleware, server lifecycle) while owning the full route
//// table and request dispatch logic.

import gleam/json
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/capabilities
import scrumbringer_server/http/me_active_task
import scrumbringer_server/http/me_metrics
import scrumbringer_server/http/org_invite_links
import scrumbringer_server/http/org_invites
import scrumbringer_server/http/org_metrics
import scrumbringer_server/http/org_users
import scrumbringer_server/http/password_resets
import scrumbringer_server/http/projects
import scrumbringer_server/http/task_notes
import scrumbringer_server/http/task_positions
import scrumbringer_server/http/tasks
import wisp

/// Context required for routing, including database and JWT secret.
pub type RouterCtx {
  RouterCtx(db: pog.Connection, jwt_secret: BitArray)
}

/// Routes a request to the appropriate handler based on path segments.
///
/// ## Example
///
/// ```gleam
/// let ctx = RouterCtx(db: db, jwt_secret: secret)
/// let response = route(request, ctx)
/// ```
pub fn route(req: wisp.Request, ctx: RouterCtx) -> wisp.Response {
  use <- wisp.rescue_crashes

  case wisp.path_segments(req) {
    // Auth routes
    ["api", "v1", "auth", "register"] ->
      auth.handle_register(req, auth_ctx(ctx))
    ["api", "v1", "auth", "invite-links", token] ->
      auth.handle_invite_link_validate(req, auth_ctx(ctx), token)
    ["api", "v1", "auth", "password-resets"] ->
      password_resets.handle_password_resets(req, password_resets_ctx(ctx))
    ["api", "v1", "auth", "password-resets", "consume"] ->
      password_resets.handle_consume(req, password_resets_ctx(ctx))
    ["api", "v1", "auth", "password-resets", token] ->
      password_resets.handle_password_reset_token(
        req,
        password_resets_ctx(ctx),
        token,
      )
    ["api", "v1", "auth", "login"] -> auth.handle_login(req, auth_ctx(ctx))
    ["api", "v1", "auth", "me"] -> auth.handle_me(req, auth_ctx(ctx))
    ["api", "v1", "auth", "logout"] -> auth.handle_logout(req, auth_ctx(ctx))

    // Org routes
    ["api", "v1", "org", "invites"] ->
      org_invites.handle_create(req, auth_ctx(ctx))
    ["api", "v1", "org", "invite-links"] ->
      org_invite_links.handle_invite_links(req, auth_ctx(ctx))
    ["api", "v1", "org", "invite-links", "regenerate"] ->
      org_invite_links.handle_regenerate(req, auth_ctx(ctx))
    ["api", "v1", "org", "users"] ->
      org_users.handle_org_users(req, auth_ctx(ctx))
    ["api", "v1", "org", "users", user_id] ->
      org_users.handle_org_user(req, auth_ctx(ctx), user_id)
    ["api", "v1", "org", "metrics", "overview"] ->
      org_metrics.handle_org_metrics_overview(req, auth_ctx(ctx))
    ["api", "v1", "org", "metrics", "projects", project_id, "tasks"] ->
      org_metrics.handle_org_metrics_project_tasks(
        req,
        auth_ctx(ctx),
        project_id,
      )

    // Project routes
    ["api", "v1", "projects"] -> projects.handle_projects(req, auth_ctx(ctx))
    ["api", "v1", "projects", project_id, "members"] ->
      projects.handle_members(req, auth_ctx(ctx), project_id)
    ["api", "v1", "projects", project_id, "members", user_id] ->
      projects.handle_member_remove(req, auth_ctx(ctx), project_id, user_id)
    ["api", "v1", "projects", project_id, "task-types"] ->
      tasks.handle_task_types(req, auth_ctx(ctx), project_id)
    ["api", "v1", "projects", project_id, "tasks"] ->
      tasks.handle_project_tasks(req, auth_ctx(ctx), project_id)

    // Task routes
    ["api", "v1", "tasks", task_id, "claim"] ->
      tasks.handle_claim(req, auth_ctx(ctx), task_id)
    ["api", "v1", "tasks", task_id, "release"] ->
      tasks.handle_release(req, auth_ctx(ctx), task_id)
    ["api", "v1", "tasks", task_id, "complete"] ->
      tasks.handle_complete(req, auth_ctx(ctx), task_id)
    ["api", "v1", "tasks", task_id, "notes"] ->
      task_notes.handle_task_notes(req, auth_ctx(ctx), task_id)
    ["api", "v1", "tasks", task_id] ->
      tasks.handle_task(req, auth_ctx(ctx), task_id)

    // Capabilities routes
    ["api", "v1", "capabilities"] ->
      capabilities.handle_capabilities(req, auth_ctx(ctx))
    ["api", "v1", "me", "capabilities"] ->
      capabilities.handle_me_capabilities(req, auth_ctx(ctx))

    // Me routes
    ["api", "v1", "me", "task-positions"] ->
      task_positions.handle_me_task_positions(req, auth_ctx(ctx))
    ["api", "v1", "me", "task-positions", task_id] ->
      task_positions.handle_me_task_position(req, auth_ctx(ctx), task_id)
    ["api", "v1", "me", "active-task"] ->
      me_active_task.handle_me_active_task(req, auth_ctx(ctx))
    ["api", "v1", "me", "active-task", "start"] ->
      me_active_task.handle_me_active_task_start(req, auth_ctx(ctx))
    ["api", "v1", "me", "active-task", "pause"] ->
      me_active_task.handle_me_active_task_pause(req, auth_ctx(ctx))
    ["api", "v1", "me", "active-task", "heartbeat"] ->
      me_active_task.handle_me_active_task_heartbeat(req, auth_ctx(ctx))
    ["api", "v1", "me", "metrics"] ->
      me_metrics.handle_me_metrics(req, auth_ctx(ctx))

    // Health check
    ["api", "v1", "health"] -> api.ok(json.object([#("ok", json.bool(True))]))

    // Not found
    _ -> wisp.not_found()
  }
}

/// Converts RouterCtx to auth.Ctx for auth handlers.
fn auth_ctx(ctx: RouterCtx) -> auth.Ctx {
  let RouterCtx(db: db, jwt_secret: jwt_secret) = ctx
  auth.Ctx(db: db, jwt_secret: jwt_secret)
}

/// Converts RouterCtx to password_resets.Ctx for password reset handlers.
fn password_resets_ctx(ctx: RouterCtx) -> password_resets.Ctx {
  let RouterCtx(db: db, ..) = ctx
  password_resets.Ctx(db: db)
}
