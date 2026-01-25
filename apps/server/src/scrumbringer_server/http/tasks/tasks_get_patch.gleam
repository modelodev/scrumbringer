//// Task get and patch HTTP handler helpers.

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None}
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

pub fn handle_task_get(
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

          case workflow.handle(db, workflow_types.GetTask(task_id, user.id)) {
            Ok(workflow_types.TaskResult(task)) ->
              api.ok(json.object([#("task", presenters.task_json(task))]))

            Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
            Error(workflow_types.NotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(workflow_types.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
          }
        }
      }
  }
}

pub fn handle_task_patch(
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
                  None,
                  decode.optional(decode.string),
                )
                use description <- decode.optional_field(
                  "description",
                  None,
                  decode.optional(decode.string),
                )
                use priority <- decode.optional_field(
                  "priority",
                  None,
                  decode.optional(decode.int),
                )
                use type_id <- decode.optional_field(
                  "type_id",
                  None,
                  decode.optional(decode.int),
                )
                decode.success(#(version, title, description, priority, type_id))
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(#(version, title, description, priority, type_id)) -> {
                  let updates =
                    workflow_types.TaskUpdates(
                      title: workflow_types.field_update_from_option(title),
                      description: workflow_types.field_update_from_option(
                        description,
                      ),
                      priority: workflow_types.field_update_from_option(
                        priority,
                      ),
                      type_id: workflow_types.field_update_from_option(type_id),
                    )

                  case
                    workflow.handle(
                      db,
                      workflow_types.UpdateTask(
                        task_id,
                        user.id,
                        version,
                        updates,
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
                    Error(workflow_types.VersionConflict) ->
                      conflict_handlers.handle_version_or_claim_conflict(
                        db,
                        task_id,
                        user.id,
                      )
                    Error(workflow_types.ValidationError(msg)) ->
                      api.error(422, "VALIDATION_ERROR", msg)
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
}
