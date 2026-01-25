//// Task list and create HTTP handler helpers.

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/filters
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

pub fn handle_tasks_list(
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
              case
                workflow.handle(
                  db,
                  workflow_types.ListTasks(project_id, user.id, task_filters),
                )
              {
                Ok(workflow_types.TasksList(tasks)) ->
                  api.ok(
                    json.object([
                      #("tasks", json.array(tasks, of: presenters.task_json)),
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
  }
}

pub fn handle_tasks_create(
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
                use card_id <- decode.optional_field("card_id", 0, decode.int)
                decode.success(#(title, description, priority, type_id, card_id))
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(#(title, description, priority, type_id, card_id)) ->
                  case
                    workflow.handle(
                      db,
                      workflow_types.CreateTask(
                        project_id,
                        user.id,
                        user.org_id,
                        title,
                        description,
                        priority,
                        type_id,
                        card_id,
                      ),
                    )
                  {
                    Ok(workflow_types.TaskResult(task)) ->
                      api.ok(
                        json.object([#("task", presenters.task_json(task))]),
                      )

                    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
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
