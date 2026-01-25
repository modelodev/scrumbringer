//// Task type HTTP handler helpers.

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

pub fn handle_task_types_list(
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

          case
            workflow.handle(
              db,
              workflow_types.ListTaskTypes(project_id, user.id),
            )
          {
            Ok(workflow_types.TaskTypesList(task_types)) ->
              api.ok(
                json.object([
                  #(
                    "task_types",
                    json.array(task_types, of: presenters.task_type_json),
                  ),
                ]),
              )

            Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
            Error(workflow_types.NotAuthorized) ->
              api.error(403, "FORBIDDEN", "Forbidden")
            Error(workflow_types.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
          }
        }
      }
  }
}

pub fn handle_task_types_create(
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
                    workflow.handle(
                      db,
                      workflow_types.CreateTaskType(
                        project_id,
                        user.id,
                        user.org_id,
                        name,
                        icon,
                        cap_opt,
                      ),
                    )
                  {
                    Ok(workflow_types.TaskTypeCreated(task_type)) ->
                      api.ok(
                        json.object([
                          #("task_type", presenters.task_type_json(task_type)),
                        ]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(workflow_types.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
                    Error(workflow_types.TaskTypeAlreadyExists) ->
                      api.error(
                        422,
                        "VALIDATION_ERROR",
                        "Task type name already exists",
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

/// Story 4.9 AC13: Update task type (PATCH).
pub fn handle_task_type_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  type_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(type_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(type_id) -> {
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
                    workflow.handle(
                      db,
                      workflow_types.UpdateTaskType(
                        type_id,
                        user.id,
                        name,
                        icon,
                        cap_opt,
                      ),
                    )
                  {
                    Ok(workflow_types.TaskTypeUpdated(task_type)) ->
                      api.ok(
                        json.object([
                          #("task_type", presenters.task_type_json(task_type)),
                        ]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                    Error(workflow_types.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(workflow_types.NotAuthorized) ->
                      api.error(403, "FORBIDDEN", "Forbidden")
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

/// Story 4.9 AC14: Delete task type (DELETE).
pub fn handle_task_type_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  type_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(type_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(type_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case
                workflow.handle(
                  db,
                  workflow_types.DeleteTaskType(type_id, user.id),
                )
              {
                Ok(workflow_types.TaskTypeDeleted(deleted_id)) ->
                  api.ok(json.object([#("id", json.int(deleted_id))]))

                Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
                Error(workflow_types.NotFound) ->
                  api.error(404, "NOT_FOUND", "Not found")
                Error(workflow_types.TaskTypeInUse) ->
                  api.error(409, "CONFLICT", "Task type is in use by tasks")
                Error(workflow_types.NotAuthorized) ->
                  api.error(403, "FORBIDDEN", "Forbidden")
                Error(workflow_types.DbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")
                Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
              }
            }
          }
      }
  }
}
