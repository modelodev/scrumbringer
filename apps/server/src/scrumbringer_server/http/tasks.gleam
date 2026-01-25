//// Task HTTP handlers for Scrumbringer server.
////
//// ## Mission
////
//// Provides HTTP route handlers for task-related operations including
//// task types, tasks, and task state transitions (claim, release, complete).
//// Delegates business logic to task_workflow_actor.
////
//// ## Responsibilities
////
//// - HTTP method validation
//// - Authentication checks
//// - Request body parsing
//// - CSRF validation
//// - Response JSON construction
//// - Error mapping to HTTP status codes
////
//// ## Non-responsibilities
////
//// - Business logic (see `services/workflows/handlers.gleam`)
//// - Input validation (see `services/workflows/validation.gleam`)
//// - Database operations (see `persistence/tasks/queries.gleam`)
////
//// ## Submodules
////
//// - `tasks/task_types_handlers`: task type list/create/update/delete
//// - `tasks/tasks_list_create`: task list/create endpoints
//// - `tasks/tasks_get_patch`: task get/patch endpoints
//// - `tasks/tasks_transitions`: claim/release/complete endpoints
//// - `tasks/presenters`: JSON serialization functions
//// - `tasks/filters`: Query parameter parsing

import gleam/http
import scrumbringer_server/http/auth
import scrumbringer_server/http/tasks/task_types_handlers
import scrumbringer_server/http/tasks/tasks_get_patch
import scrumbringer_server/http/tasks/tasks_list_create
import scrumbringer_server/http/tasks/tasks_transitions
import wisp

// =============================================================================
// Route Handlers
// =============================================================================

/// Handle task types routes (GET list, POST create).
pub fn handle_task_types(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> task_types_handlers.handle_task_types_list(req, ctx, project_id)
    http.Post ->
      task_types_handlers.handle_task_types_create(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle single task type routes (PATCH, DELETE).
/// Story 4.9 AC13-14
pub fn handle_task_type(
  req: wisp.Request,
  ctx: auth.Ctx,
  type_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> task_types_handlers.handle_task_type_update(req, ctx, type_id)
    http.Delete ->
      task_types_handlers.handle_task_type_delete(req, ctx, type_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

/// Handle project tasks routes (GET list, POST create).
pub fn handle_project_tasks(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> tasks_list_create.handle_tasks_list(req, ctx, project_id)
    http.Post -> tasks_list_create.handle_tasks_create(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle single task routes (GET, PATCH).
pub fn handle_task(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> tasks_get_patch.handle_task_get(req, ctx, task_id)
    http.Patch -> tasks_get_patch.handle_task_patch(req, ctx, task_id)
    _ -> wisp.method_not_allowed([http.Get, http.Patch])
  }
}

/// Handle task claim (POST).
pub fn handle_claim(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  tasks_transitions.handle_task_claim(req, ctx, task_id)
}

/// Handle task release (POST).
pub fn handle_release(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  tasks_transitions.handle_task_release(req, ctx, task_id)
}

/// Handle task complete (POST).
pub fn handle_complete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  tasks_transitions.handle_task_complete(req, ctx, task_id)
}
