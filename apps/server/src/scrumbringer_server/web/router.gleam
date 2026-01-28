//// HTTP Router
////
//// ## Mission
////
//// Centralize API route matching and dispatch to HTTP handlers.
////
//// ## Responsibilities
////
//// - Map path segments to handler functions
//// - Provide handler contexts derived from RouterCtx
////
//// ## Non-responsibilities
////
//// - Implementing business logic (handled by HTTP modules)
//// - Request parsing beyond routing (handled by handlers)
////
//// ## Relations
////
//// - Uses `http/*` modules for request handling
//// - Receives `RouterCtx` from `scrumbringer_server.gleam`

import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/capabilities
import scrumbringer_server/http/card_notes
import scrumbringer_server/http/card_views
import scrumbringer_server/http/cards
import scrumbringer_server/http/me_metrics
import scrumbringer_server/http/org_invite_links
import scrumbringer_server/http/org_invites
import scrumbringer_server/http/org_metrics
import scrumbringer_server/http/org_users
import scrumbringer_server/http/password_resets
import scrumbringer_server/http/projects
import scrumbringer_server/http/rule_metrics
import scrumbringer_server/http/rules
import scrumbringer_server/http/task_notes
import scrumbringer_server/http/task_positions
import scrumbringer_server/http/task_templates
import scrumbringer_server/http/tasks
import scrumbringer_server/http/work_sessions
import scrumbringer_server/http/workflows
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

  let segments = wisp.path_segments(req)
  let routes = [
    route_auth,
    route_org,
    route_projects,
    route_task_templates,
    route_workflows,
    route_rules,
    route_rule_metrics,
    route_cards,
    route_tasks,
    route_capabilities,
    route_me,
    route_health,
  ]

  case find_route(routes, segments, req, ctx) {
    Some(resp) -> resp
    None -> wisp.not_found()
  }
}

type RouteFn =
  fn(List(String), wisp.Request, RouterCtx) -> Option(wisp.Response)

// Justification: nested case improves clarity for branching logic.
fn find_route(
  routes: List(RouteFn),
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  case routes {
    [] -> None
    [route, ..rest] ->
      // Justified nested case: stop at the first matching route.
      case route(segments, req, ctx) {
        Some(resp) -> Some(resp)
        None -> find_route(rest, segments, req, ctx)
      }
  }
}

fn route_auth(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  let auth_ctx = auth_ctx(ctx)
  let reset_ctx = password_resets_ctx(ctx)

  case segments {
    ["api", "v1", "auth", "register"] ->
      Some(auth.handle_register(req, auth_ctx))
    ["api", "v1", "auth", "invite-links", token] ->
      Some(auth.handle_invite_link_validate(req, auth_ctx, token))
    ["api", "v1", "auth", "password-resets"] ->
      Some(password_resets.handle_password_resets(req, reset_ctx))
    ["api", "v1", "auth", "password-resets", "consume"] ->
      Some(password_resets.handle_consume(req, reset_ctx))
    ["api", "v1", "auth", "password-resets", token] ->
      Some(password_resets.handle_password_reset_token(req, reset_ctx, token))
    ["api", "v1", "auth", "login"] -> Some(auth.handle_login(req, auth_ctx))
    ["api", "v1", "auth", "me"] -> Some(auth.handle_me(req, auth_ctx))
    ["api", "v1", "auth", "logout"] -> Some(auth.handle_logout(req, auth_ctx))
    _ -> None
  }
}

fn route_org(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  let auth_ctx = auth_ctx(ctx)

  case segments {
    ["api", "v1", "org", "invites"] ->
      Some(org_invites.handle_create(req, auth_ctx))
    ["api", "v1", "org", "invite-links"] ->
      Some(org_invite_links.handle_invite_links(req, auth_ctx))
    ["api", "v1", "org", "invite-links", "regenerate"] ->
      Some(org_invite_links.handle_regenerate(req, auth_ctx))
    ["api", "v1", "org", "users"] ->
      Some(org_users.handle_org_users(req, auth_ctx))
    ["api", "v1", "org", "users", user_id] ->
      Some(org_users.handle_org_user(req, auth_ctx, user_id))
    ["api", "v1", "org", "users", user_id, "projects"] ->
      Some(org_users.handle_user_projects(req, auth_ctx, user_id))
    ["api", "v1", "org", "users", user_id, "projects", project_id] ->
      Some(org_users.handle_user_project(req, auth_ctx, user_id, project_id))
    ["api", "v1", "org", "metrics", "overview"] ->
      Some(org_metrics.handle_org_metrics_overview(req, auth_ctx))
    ["api", "v1", "org", "metrics", "projects", project_id, "tasks"] ->
      Some(org_metrics.handle_org_metrics_project_tasks(
        req,
        auth_ctx,
        project_id,
      ))
    _ -> None
  }
}

fn route_projects(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  let auth_ctx = auth_ctx(ctx)

  case segments {
    ["api", "v1", "projects"] -> Some(projects.handle_projects(req, auth_ctx))
    ["api", "v1", "projects", project_id] ->
      Some(projects.handle_project(req, auth_ctx, project_id))
    ["api", "v1", "projects", project_id, "members"] ->
      Some(projects.handle_members(req, auth_ctx, project_id))
    ["api", "v1", "projects", project_id, "members", user_id] ->
      Some(projects.handle_member(req, auth_ctx, project_id, user_id))
    ["api", "v1", "projects", project_id, "task-types"] ->
      Some(tasks.handle_task_types(req, auth_ctx, project_id))
    ["api", "v1", "task-types", type_id] ->
      Some(tasks.handle_task_type(req, auth_ctx, type_id))
    ["api", "v1", "projects", project_id, "tasks"] ->
      Some(tasks.handle_project_tasks(req, auth_ctx, project_id))
    ["api", "v1", "projects", project_id, "task-templates"] ->
      Some(task_templates.handle_project_templates(req, auth_ctx, project_id))
    ["api", "v1", "projects", project_id, "workflows"] ->
      Some(workflows.handle_project_workflows(req, auth_ctx, project_id))
    _ -> None
  }
}

fn route_task_templates(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  case segments {
    ["api", "v1", "task-templates", template_id] ->
      Some(task_templates.handle_template(req, auth_ctx(ctx), template_id))
    _ -> None
  }
}

fn route_workflows(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  case segments {
    ["api", "v1", "workflows", workflow_id] ->
      Some(workflows.handle_workflow(req, auth_ctx(ctx), workflow_id))
    _ -> None
  }
}

fn route_rules(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  case segments {
    ["api", "v1", "workflows", workflow_id, "rules"] ->
      Some(rules.handle_workflow_rules(req, auth_ctx(ctx), workflow_id))
    ["api", "v1", "rules", rule_id] ->
      Some(rules.handle_rule(req, auth_ctx(ctx), rule_id))
    ["api", "v1", "rules", rule_id, "templates", template_id] ->
      Some(rules.handle_rule_template(req, auth_ctx(ctx), rule_id, template_id))
    _ -> None
  }
}

fn route_rule_metrics(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  case segments {
    ["api", "v1", "workflows", workflow_id, "metrics"] ->
      Some(rule_metrics.handle_workflow_metrics(req, auth_ctx(ctx), workflow_id))
    ["api", "v1", "rules", rule_id, "metrics"] ->
      Some(rule_metrics.handle_rule_metrics(req, auth_ctx(ctx), rule_id))
    ["api", "v1", "rules", rule_id, "executions"] ->
      Some(rule_metrics.handle_rule_executions(req, auth_ctx(ctx), rule_id))
    ["api", "v1", "org", "rule-metrics"] ->
      Some(rule_metrics.handle_org_metrics(req, auth_ctx(ctx)))
    ["api", "v1", "projects", project_id, "rule-metrics"] ->
      Some(rule_metrics.handle_project_metrics(req, auth_ctx(ctx), project_id))
    _ -> None
  }
}

// Justification: nested case improves clarity for branching logic.
fn route_cards(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  // Justified nested case: parse numeric path segments for card routing.
  case segments {
    ["api", "v1", "projects", project_id, "cards"] ->
      case parse_int_segment(project_id) {
        Some(pid) -> Some(cards.handle_project_cards(req, auth_ctx(ctx), pid))
        None -> Some(wisp.not_found())
      }

    ["api", "v1", "cards", card_id, "notes", note_id] ->
      Some(card_notes.handle_card_note(req, auth_ctx(ctx), card_id, note_id))

    ["api", "v1", "cards", card_id, "notes"] ->
      Some(card_notes.handle_card_notes(req, auth_ctx(ctx), card_id))

    ["api", "v1", "views", "cards", card_id] ->
      Some(card_views.handle_card_view(req, auth_ctx(ctx), card_id))

    ["api", "v1", "cards", card_id] ->
      case parse_int_segment(card_id) {
        Some(cid) -> Some(cards.handle_card(req, auth_ctx(ctx), cid))
        None -> Some(wisp.not_found())
      }

    _ -> None
  }
}

fn route_tasks(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  let auth_ctx = auth_ctx(ctx)

  case segments {
    ["api", "v1", "tasks", task_id, "claim"] ->
      Some(tasks.handle_claim(req, auth_ctx, task_id))
    ["api", "v1", "tasks", task_id, "release"] ->
      Some(tasks.handle_release(req, auth_ctx, task_id))
    ["api", "v1", "tasks", task_id, "complete"] ->
      Some(tasks.handle_complete(req, auth_ctx, task_id))
    ["api", "v1", "tasks", task_id, "notes"] ->
      Some(task_notes.handle_task_notes(req, auth_ctx, task_id))
    ["api", "v1", "tasks", task_id] ->
      Some(tasks.handle_task(req, auth_ctx, task_id))
    _ -> None
  }
}

// Justification: nested case improves clarity for branching logic.
fn route_capabilities(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  let auth_ctx = auth_ctx(ctx)
  // Justified nested case: parse numeric path segments for capability routing.
  case segments {
    ["api", "v1", "projects", project_id, "capabilities"] ->
      case parse_int_segment(project_id) {
        Some(pid) ->
          Some(capabilities.handle_project_capabilities(req, auth_ctx, pid))
        None -> Some(wisp.not_found())
      }

    ["api", "v1", "projects", project_id, "members", user_id, "capabilities"] ->
      case parse_int_segment(project_id), parse_int_segment(user_id) {
        Some(pid), Some(uid) ->
          Some(capabilities.handle_member_capabilities(req, auth_ctx, pid, uid))
        _, _ -> Some(wisp.not_found())
      }

    [
      "api",
      "v1",
      "projects",
      project_id,
      "capabilities",
      capability_id,
      "members",
    ] ->
      case parse_int_segment(project_id), parse_int_segment(capability_id) {
        Some(pid), Some(cid) ->
          Some(capabilities.handle_capability_members(req, auth_ctx, pid, cid))
        _, _ -> Some(wisp.not_found())
      }

    ["api", "v1", "projects", project_id, "capabilities", capability_id] ->
      case parse_int_segment(project_id), parse_int_segment(capability_id) {
        Some(pid), Some(cid) ->
          Some(capabilities.handle_capability(req, auth_ctx, pid, cid))
        _, _ -> Some(wisp.not_found())
      }

    _ -> None
  }
}

fn route_me(
  segments: List(String),
  req: wisp.Request,
  ctx: RouterCtx,
) -> Option(wisp.Response) {
  let auth_ctx = auth_ctx(ctx)

  case segments {
    ["api", "v1", "me", "task-positions"] ->
      Some(task_positions.handle_me_task_positions(req, auth_ctx))
    ["api", "v1", "me", "task-positions", task_id] ->
      Some(task_positions.handle_me_task_position(req, auth_ctx, task_id))
    ["api", "v1", "me", "work-sessions", "active"] ->
      Some(work_sessions.handle_get_active(req, auth_ctx))
    ["api", "v1", "me", "work-sessions", "start"] ->
      Some(work_sessions.handle_start(req, auth_ctx))
    ["api", "v1", "me", "work-sessions", "pause"] ->
      Some(work_sessions.handle_pause(req, auth_ctx))
    ["api", "v1", "me", "work-sessions", "heartbeat"] ->
      Some(work_sessions.handle_heartbeat(req, auth_ctx))
    ["api", "v1", "me", "active-task"] ->
      Some(work_sessions.handle_get_active(req, auth_ctx))
    ["api", "v1", "me", "active-task", "start"] ->
      Some(work_sessions.handle_start(req, auth_ctx))
    ["api", "v1", "me", "active-task", "pause"] ->
      Some(work_sessions.handle_pause(req, auth_ctx))
    ["api", "v1", "me", "active-task", "heartbeat"] ->
      Some(work_sessions.handle_heartbeat(req, auth_ctx))
    ["api", "v1", "me", "metrics"] ->
      Some(me_metrics.handle_me_metrics(req, auth_ctx))
    _ -> None
  }
}

fn route_health(
  segments: List(String),
  _req: wisp.Request,
  _ctx: RouterCtx,
) -> Option(wisp.Response) {
  case segments {
    ["api", "v1", "health"] ->
      Some(api.ok(json.object([#("ok", json.bool(True))])))
    _ -> None
  }
}

fn parse_int_segment(value: String) -> Option(Int) {
  case int.parse(value) {
    Ok(value) -> Some(value)
    Error(_) -> None
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
