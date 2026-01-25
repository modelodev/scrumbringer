//// Task state transition HTTP handler helpers.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

pub fn handle_task_claim(
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
                    workflow.handle(
                      db,
                      workflow_types.ClaimTask(
                        task_id,
                        user.id,
                        user.org_id,
                        version,
                      ),
                    )
                  {
                    Ok(workflow_types.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(workflow_types.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(workflow_types.AlreadyClaimed) ->
                      api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
                    Error(workflow_types.InvalidTransition) ->
                      api.error(422, "VALIDATION_ERROR", "Invalid transition")
                    Error(workflow_types.ClaimOwnershipConflict(_)) ->
                      api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
                    Error(workflow_types.VersionConflict) ->
                      conflict_handlers.handle_claim_conflict(
                        db,
                        task_id,
                        user.id,
                      )
                    Error(workflow_types.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
              }
            }
          }
      }
  }
}

pub fn handle_task_release(
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
                    workflow.handle(
                      db,
                      workflow_types.ReleaseTask(
                        task_id,
                        user.id,
                        user.org_id,
                        version,
                      ),
                    )
                  {
                    Ok(workflow_types.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(workflow_types.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(workflow_types.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(workflow_types.InvalidTransition) ->
                      api.error(422, "VALIDATION_ERROR", "Invalid transition")
                    Error(workflow_types.VersionConflict) ->
                      conflict_handlers.handle_version_or_claim_conflict(
                        db,
                        task_id,
                        user.id,
                      )
                    Error(workflow_types.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
              }
            }
          }
      }
  }
}

pub fn handle_task_complete(
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
                    workflow.handle(
                      db,
                      workflow_types.CompleteTask(
                        task_id,
                        user.id,
                        user.org_id,
                        version,
                      ),
                    )
                  {
                    Ok(workflow_types.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(workflow_types.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(workflow_types.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(workflow_types.InvalidTransition) ->
                      api.error(422, "VALIDATION_ERROR", "Invalid transition")
                    Error(workflow_types.VersionConflict) ->
                      conflict_handlers.handle_version_or_claim_conflict(
                        db,
                        task_id,
                        user.id,
                      )
                    Error(workflow_types.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                  }
              }
            }
          }
      }
  }
}
