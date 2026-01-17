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
//// - Business logic (see `services/task_workflow_actor.gleam`)
//// - Input validation (see `services/task_workflow_actor.gleam`)
//// - Database operations (see `services/tasks_db.gleam`)
////
//// ## Submodules
////
//// - `tasks/presenters`: JSON serialization functions
//// - `tasks/filters`: Query parameter parsing

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/filters
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/task_workflow_actor as actor
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
    http.Get -> handle_task_types_list(req, ctx, project_id)
    http.Post -> handle_task_types_create(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle project tasks routes (GET list, POST create).
pub fn handle_project_tasks(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_tasks_list(req, ctx, project_id)
    http.Post -> handle_tasks_create(req, ctx, project_id)
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
    http.Get -> handle_task_get(req, ctx, task_id)
    http.Patch -> handle_task_patch(req, ctx, task_id)
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
  handle_task_claim(req, ctx, task_id)
}

/// Handle task release (POST).
pub fn handle_release(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  handle_task_release(req, ctx, task_id)
}

/// Handle task complete (POST).
pub fn handle_complete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  handle_task_complete(req, ctx, task_id)
}

// =============================================================================
// Task Types Handlers
// =============================================================================

fn handle_task_types_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case actor.handle(db, actor.ListTaskTypes(project_id, user.id)) {
            Ok(actor.TaskTypesList(task_types)) ->
              api.ok(
                json.object([
                  #(
                    "task_types",
                    json.array(task_types, of: presenters.task_type_json),
                  ),
                ]),
              )

            Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
            Error(actor.NotAuthorized) ->
              api.error(403, "FORBIDDEN", "Forbidden")
            Error(actor.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
          }
        }
      }
  }
}

fn handle_task_types_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(project_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(project_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use name <- decode.field("name", decode.string)
                use icon <- decode.field("icon", decode.string)
                use capability_id <- decode.optional_field(
                  "capability_id",
                  0,
                  decode.int,
                )
                decode.success(#(name, icon, capability_id))
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(#(name, icon, capability_id)) -> {
                  let cap_opt = case capability_id {
                    0 -> None
                    id -> Some(id)
                  }

                  case
                    actor.handle(
                      db,
                      actor.CreateTaskType(
                        project_id,
                        user.id,
                        user.org_id,
                        name,
                        icon,
                        cap_opt,
                      ),
                    )
                  {
                    Ok(actor.TaskTypeCreated(task_type)) ->
                      api.ok(
                        json.object([
                          #("task_type", presenters.task_type_json(task_type)),
                        ]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(actor.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(actor.TaskTypeAlreadyExists) ->
                      api.error(
                        422,
                        "VALIDATION_ERROR",
                        "Task type name already exists",
                      )
                    Error(actor.ValidationError(msg)) ->
                      api.error(422, "VALIDATION_ERROR", msg)
                    Error(actor.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
                }
              }
            }
          }
      }
  }
}

// =============================================================================
// Tasks Handlers
// =============================================================================

fn handle_tasks_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx
          let query = wisp.get_query(req)

          case filters.parse_task_filters(query) {
            Error(resp) -> resp

            Ok(task_filters) -> {
              let actor_filters =
                actor.TaskFilters(
                  status: filters.status_filter_to_db_string(
                    task_filters.status,
                  ),
                  type_id: task_filters.type_id,
                  capability_id: task_filters.capability_id,
                  q: task_filters.q,
                )

              case
                actor.handle(
                  db,
                  actor.ListTasks(project_id, user.id, actor_filters),
                )
              {
                Ok(actor.TasksList(tasks)) ->
                  api.ok(
                    json.object([
                      #("tasks", json.array(tasks, of: presenters.task_json)),
                    ]),
                  )

                Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                Error(actor.NotAuthorized) ->
                  api.error(403, "FORBIDDEN", "Forbidden")
                Error(actor.DbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")
                Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
              }
            }
          }
        }
      }
  }
}

fn handle_tasks_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(project_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(project_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use title <- decode.field("title", decode.string)
                use description <- decode.optional_field(
                  "description",
                  "",
                  decode.string,
                )
                use priority <- decode.field("priority", decode.int)
                use type_id <- decode.field("type_id", decode.int)
                decode.success(#(title, description, priority, type_id))
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(#(title, description, priority, type_id)) ->
                  case
                    actor.handle(
                      db,
                      actor.CreateTask(
                        project_id,
                        user.id,
                        user.org_id,
                        title,
                        description,
                        priority,
                        type_id,
                      ),
                    )
                  {
                    Ok(actor.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(actor.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(actor.ValidationError(msg)) ->
                      api.error(422, "VALIDATION_ERROR", msg)
                    Error(actor.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
              }
            }
          }
      }
  }
}

fn handle_task_get(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(task_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(task_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case actor.handle(db, actor.GetTask(task_id, user.id)) {
            Ok(actor.TaskResult(task)) ->
              api.ok(json.object([#("task", presenters.task_json(task))]))

            Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
            Error(actor.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
            Error(actor.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
          }
        }
      }
  }
}

fn handle_task_patch(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Patch)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                use title <- decode.optional_field(
                  "title",
                  actor.unset_string,
                  decode.string,
                )
                use description <- decode.optional_field(
                  "description",
                  actor.unset_string,
                  decode.string,
                )
                use priority <- decode.optional_field(
                  "priority",
                  -1,
                  decode.int,
                )
                use type_id <- decode.optional_field("type_id", -1, decode.int)
                decode.success(#(version, title, description, priority, type_id))
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(#(version, title, description, priority, type_id)) -> {
                  let updates =
                    actor.TaskUpdates(
                      title: title,
                      description: description,
                      priority: priority,
                      type_id: type_id,
                    )

                  case
                    actor.handle(
                      db,
                      actor.UpdateTask(task_id, user.id, version, updates),
                    )
                  {
                    Ok(actor.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(actor.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(actor.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(actor.VersionConflict) ->
                      handle_version_conflict(db, task_id, user.id)
                    Error(actor.ValidationError(msg)) ->
                      api.error(422, "VALIDATION_ERROR", msg)
                    Error(actor.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
                }
              }
            }
          }
      }
  }
}

// =============================================================================
// State Transition Handlers
// =============================================================================

fn handle_task_claim(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                decode.success(version)
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(version) ->
                  case
                    actor.handle(
                      db,
                      actor.ClaimTask(task_id, user.id, user.org_id, version),
                    )
                  {
                    Ok(actor.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(actor.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(actor.AlreadyClaimed) ->
                      api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
                    Error(actor.InvalidTransition) ->
                      api.error(422, "VALIDATION_ERROR", "Invalid transition")
                    Error(actor.ClaimOwnershipConflict(_)) ->
                      api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
                    Error(actor.VersionConflict) ->
                      handle_claim_conflict(db, task_id, user.id)
                    Error(actor.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
              }
            }
          }
      }
  }
}

fn handle_task_release(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                decode.success(version)
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(version) ->
                  case
                    actor.handle(
                      db,
                      actor.ReleaseTask(task_id, user.id, user.org_id, version),
                    )
                  {
                    Ok(actor.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(actor.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(actor.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(actor.InvalidTransition) ->
                      api.error(422, "VALIDATION_ERROR", "Invalid transition")
                    Error(actor.VersionConflict) ->
                      handle_version_conflict(db, task_id, user.id)
                    Error(actor.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
              }
            }
          }
      }
  }
}

fn handle_task_complete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                decode.success(version)
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(version) ->
                  case
                    actor.handle(
                      db,
                      actor.CompleteTask(task_id, user.id, user.org_id, version),
                    )
                  {
                    Ok(actor.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(actor.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(actor.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(actor.InvalidTransition) ->
                      api.error(422, "VALIDATION_ERROR", "Invalid transition")
                    Error(actor.VersionConflict) ->
                      handle_version_conflict(db, task_id, user.id)
                    Error(actor.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
              }
            }
          }
      }
  }
}

// =============================================================================
// Conflict Handling
// =============================================================================

fn handle_version_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  conflict_handlers.handle_version_or_claim_conflict(db, task_id, user_id)
}

fn handle_claim_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  conflict_handlers.handle_claim_conflict(db, task_id, user_id)
}
