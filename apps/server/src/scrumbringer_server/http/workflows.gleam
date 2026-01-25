////
//// HTTP handlers for workflows CRUD endpoints.

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import helpers/json as json_helpers
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/workflows_db
import wisp

// =============================================================================
// Routing
// =============================================================================

pub fn handle_project_workflows(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list_project(req, ctx, project_id)
    http.Post -> handle_create_project(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_update(req, ctx, workflow_id)
    http.Delete -> handle_delete(req, ctx, workflow_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

// =============================================================================
// Handlers
// =============================================================================

fn handle_list_project(
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

          case projects_db.is_project_manager(db, project_id, user.id) {
            Ok(True) ->
              case workflows_db.list_project_workflows(db, project_id) {
                Ok(workflows) ->
                  api.ok(
                    json.object([
                      #("workflows", json.array(workflows, of: workflow_json)),
                    ]),
                  )
                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }

            Ok(False) -> api.error(403, "FORBIDDEN", "Forbidden")
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn handle_create_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case projects_db.is_project_manager(db, project_id, user.id) {
            Ok(True) ->
              create_workflow(req, ctx, user.org_id, project_id, user.id)
            Ok(False) -> api.error(403, "FORBIDDEN", "Forbidden")
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(workflow_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(workflow_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case workflows_db.get_workflow(db, workflow_id) {
            Ok(workflow) ->
              case
                authorization.require_project_manager(
                  db,
                  user,
                  workflow.org_id,
                  workflow.project_id,
                )
              {
                Error(resp) -> resp
                Ok(#(org_id, project_id)) ->
                  update_workflow(req, ctx, workflow_id, org_id, project_id)
              }

            Error(workflows_db.UpdateWorkflowNotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(workflows_db.UpdateWorkflowAlreadyExists) ->
              api.error(422, "VALIDATION_ERROR", "Workflow name already exists")
            Error(workflows_db.UpdateWorkflowDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(workflow_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(workflow_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case workflows_db.get_workflow(db, workflow_id) {
            Ok(workflow) ->
              case
                authorization.require_project_manager(
                  db,
                  user,
                  workflow.org_id,
                  workflow.project_id,
                )
              {
                Error(resp) -> resp
                Ok(#(org_id, project_id)) ->
                  case csrf.require_double_submit(req) {
                    Error(_) ->
                      api.error(
                        403,
                        "FORBIDDEN",
                        "CSRF token missing or invalid",
                      )
                    Ok(Nil) ->
                      case
                        workflows_db.delete_workflow(
                          db,
                          workflow_id,
                          org_id,
                          project_id,
                        )
                      {
                        Ok(Nil) -> api.no_content()
                        Error(workflows_db.DeleteWorkflowNotFound) ->
                          api.error(404, "NOT_FOUND", "Not found")
                        Error(workflows_db.DeleteWorkflowDbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")
                      }
                  }
              }

            Error(workflows_db.UpdateWorkflowNotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(workflows_db.UpdateWorkflowAlreadyExists) ->
              api.error(422, "VALIDATION_ERROR", "Workflow name already exists")
            Error(workflows_db.UpdateWorkflowDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

fn create_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use name <- decode.field("name", decode.string)
        use description <- decode.optional_field(
          "description",
          "",
          decode.string,
        )
        use active <- decode.optional_field("active", False, decode.bool)
        decode.success(#(name, description, active))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(name, description, active)) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            workflows_db.create_workflow(
              db,
              org_id,
              project_id,
              name,
              description,
              active,
              user_id,
            )
          {
            Ok(workflow) ->
              api.ok(json.object([#("workflow", workflow_json(workflow))]))
            Error(workflows_db.CreateWorkflowAlreadyExists) ->
              api.error(422, "VALIDATION_ERROR", "Workflow name already exists")
            Error(workflows_db.CreateWorkflowDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn update_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use name <- decode.optional_field(
          "name",
          None,
          decode.optional(decode.string),
        )
        use description <- decode.optional_field(
          "description",
          None,
          decode.optional(decode.string),
        )
        use active <- decode.optional_field(
          "active",
          None,
          decode.optional(decode.int),
        )
        decode.success(#(name, description, active))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(name, description, active)) -> {
          let auth.Ctx(db: db, ..) = ctx

          let active_value = case active {
            None -> Ok(None)
            Some(0) -> Ok(Some(False))
            Some(1) -> Ok(Some(True))
            Some(_) ->
              Error(api.error(422, "VALIDATION_ERROR", "Invalid active"))
          }

          case active_value {
            Error(response) -> response

            Ok(active_value) -> {
              let has_updates = case name, description {
                None, None -> False
                _, _ -> True
              }

              let update_result = case has_updates {
                True ->
                  case
                    workflows_db.update_workflow(
                      db,
                      workflow_id,
                      org_id,
                      project_id,
                      name,
                      description,
                    )
                  {
                    Ok(_) -> Ok(Nil)
                    Error(error) -> Error(error)
                  }
                False -> Ok(Nil)
              }

              case update_result {
                Error(workflows_db.UpdateWorkflowNotFound) ->
                  api.error(404, "NOT_FOUND", "Not found")
                Error(workflows_db.UpdateWorkflowAlreadyExists) ->
                  api.error(
                    422,
                    "VALIDATION_ERROR",
                    "Workflow name already exists",
                  )
                Error(workflows_db.UpdateWorkflowDbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")
                Ok(Nil) ->
                  case active_value {
                    Some(active) ->
                      case
                        workflows_db.set_active_cascade(
                          db,
                          workflow_id,
                          org_id,
                          project_id,
                          active,
                        )
                      {
                        Ok(Nil) -> get_workflow_response(db, workflow_id)
                        Error(workflows_db.UpdateWorkflowNotFound) ->
                          api.error(404, "NOT_FOUND", "Not found")
                        Error(workflows_db.UpdateWorkflowAlreadyExists) ->
                          api.error(
                            422,
                            "VALIDATION_ERROR",
                            "Workflow name already exists",
                          )
                        Error(workflows_db.UpdateWorkflowDbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")
                      }

                    None -> get_workflow_response(db, workflow_id)
                  }
              }
            }
          }
        }
      }
    }
  }
}

fn get_workflow_response(db: pog.Connection, workflow_id: Int) -> wisp.Response {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) ->
      api.ok(json.object([#("workflow", workflow_json(workflow))]))
    Error(workflows_db.UpdateWorkflowNotFound) ->
      api.error(404, "NOT_FOUND", "Not found")
    Error(workflows_db.UpdateWorkflowAlreadyExists) ->
      api.error(422, "VALIDATION_ERROR", "Workflow name already exists")
    Error(workflows_db.UpdateWorkflowDbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
  }
}

fn workflow_json(workflow: workflows_db.Workflow) -> json.Json {
  let workflows_db.Workflow(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    active: active,
    rule_count: rule_count,
    created_by: created_by,
    created_at: created_at,
  ) = workflow

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("description", json_helpers.option_string_json(description)),
    #("active", json.bool(active)),
    #("rule_count", json.int(rule_count)),
    #("created_by", json.int(created_by)),
    #("created_at", json.string(created_at)),
  ])
}
