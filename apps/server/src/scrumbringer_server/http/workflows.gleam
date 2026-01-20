////
//// HTTP handlers for workflows CRUD endpoints.

import domain/org_role.{Admin}
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import helpers/json as json_helpers
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

pub fn handle_org_workflows(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list_org(req, ctx)
    http.Post -> handle_create_org(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

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

fn handle_list_org(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case user.org_role {
        Admin ->
          case workflows_db.list_org_workflows(db, user.org_id) {
            Ok(workflows) ->
              api.ok(
                json.object([
                  #("workflows", json.array(workflows, of: workflow_json)),
                ]),
              )
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
    }
  }
}

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

          case projects_db.is_project_admin(db, project_id, user.id) {
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

fn handle_create_org(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case user.org_role {
        Admin -> create_workflow(req, ctx, user.org_id, None, user.id)
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
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

          case projects_db.is_project_admin(db, project_id, user.id) {
            Ok(True) ->
              create_workflow(req, ctx, user.org_id, Some(project_id), user.id)
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
                authorization.require_scoped_admin(
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
                authorization.require_scoped_admin(
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
  project_id: Option(Int),
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
  project_id: Option(Int),
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use name <- decode.optional_field("name", "__unset__", decode.string)
        use description <- decode.optional_field(
          "description",
          "__unset__",
          decode.string,
        )
        use active <- decode.optional_field("active", -1, decode.int)
        decode.success(#(name, description, active))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(name, description, active)) -> {
          let auth.Ctx(db: db, ..) = ctx

          let active_flag = case active {
            -1 -> -1
            0 -> 0
            _ -> 1
          }

          case active_flag {
            -1 ->
              case
                workflows_db.update_workflow(
                  db,
                  workflow_id,
                  org_id,
                  project_id,
                  name,
                  description,
                  active_flag,
                )
              {
                Ok(workflow) ->
                  api.ok(json.object([#("workflow", workflow_json(workflow))]))
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

            0 ->
              case
                workflows_db.set_active_cascade(
                  db,
                  workflow_id,
                  org_id,
                  project_id,
                  False,
                )
              {
                Ok(Nil) ->
                  case workflows_db.get_workflow(db, workflow_id) {
                    Ok(workflow) ->
                      api.ok(
                        json.object([#("workflow", workflow_json(workflow))]),
                      )
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

            _ ->
              case
                workflows_db.set_active_cascade(
                  db,
                  workflow_id,
                  org_id,
                  project_id,
                  True,
                )
              {
                Ok(Nil) ->
                  case workflows_db.get_workflow(db, workflow_id) {
                    Ok(workflow) ->
                      api.ok(
                        json.object([#("workflow", workflow_json(workflow))]),
                      )
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
          }
        }
      }
    }
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
    #("project_id", json_helpers.option_int_json(project_id)),
    #("name", json.string(name)),
    #("description", json_helpers.option_string_json(description)),
    #("active", json.bool(active)),
    #("rule_count", json.int(rule_count)),
    #("created_by", json.int(created_by)),
    #("created_at", json.string(created_at)),
  ])
}
