////
//// HTTP handlers for workflow rules CRUD and template associations.

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import helpers/json as json_helpers
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/services/rules_db
import scrumbringer_server/services/rules_target
import scrumbringer_server/services/task_templates_db
import scrumbringer_server/services/workflows_db
import wisp

pub fn handle_workflow_rules(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx, workflow_id)
    http.Post -> handle_create(req, ctx, workflow_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_rule(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_update(req, ctx, rule_id)
    http.Delete -> handle_delete(req, ctx, rule_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

pub fn handle_rule_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
  template_id: String,
) -> wisp.Response {
  case req.method {
    http.Post -> handle_attach_template(req, ctx, rule_id, template_id)
    http.Delete -> handle_detach_template(req, ctx, rule_id, template_id)
    _ -> wisp.method_not_allowed([http.Post, http.Delete])
  }
}

// =============================================================================
// Handlers
// =============================================================================

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

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
                authorization.require_project_manager_simple(
                  db,
                  user,
                  workflow.org_id,
                  workflow.project_id,
                )
              {
                Error(resp) -> resp
                Ok(Nil) ->
                  case rules_db.list_rules_for_workflow(db, workflow_id) {
                    Ok(rules) -> {
                      // Story 4.10 AC23: Include templates for each rule
                      let rules_with_templates =
                        list.map(rules, fn(rule) {
                          let templates = case
                            rules_db.list_rule_templates(db, rule.id)
                          {
                            Ok(t) -> t
                            Error(_) -> []
                          }
                          rule_json_with_templates(rule, templates)
                        })
                      api.ok(
                        json.object([
                          #(
                            "rules",
                            json.preprocessed_array(rules_with_templates),
                          ),
                        ]),
                      )
                    }
                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn handle_create(
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
                authorization.require_project_manager_simple(
                  db,
                  user,
                  workflow.org_id,
                  workflow.project_id,
                )
              {
                Error(resp) -> resp
                Ok(Nil) -> create_rule(req, ctx, workflow_id)
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(rule_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(rule_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case rules_db.get_rule(db, rule_id) {
            Ok(rule) ->
              case workflow_from_rule(db, rule) {
                Error(resp) -> resp
                Ok(workflow) ->
                  case
                    authorization.require_project_manager_simple(
                      db,
                      user,
                      workflow.org_id,
                      workflow.project_id,
                    )
                  {
                    Error(resp) -> resp
                    Ok(Nil) -> update_rule(req, ctx, rule_id)
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(rule_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(rule_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case rules_db.get_rule(db, rule_id) {
            Ok(rule) ->
              case workflow_from_rule(db, rule) {
                Error(resp) -> resp
                Ok(workflow) ->
                  case
                    authorization.require_project_manager_simple(
                      db,
                      user,
                      workflow.org_id,
                      workflow.project_id,
                    )
                  {
                    Error(resp) -> resp
                    Ok(Nil) ->
                      case csrf.require_double_submit(req) {
                        Error(_) ->
                          api.error(
                            403,
                            "FORBIDDEN",
                            "CSRF token missing or invalid",
                          )
                        Ok(Nil) ->
                          case rules_db.delete_rule(db, rule_id) {
                            Ok(Nil) -> api.no_content()
                            Error(rules_db.DeleteNotFound) ->
                              api.error(404, "NOT_FOUND", "Not found")
                            Error(rules_db.DeleteDbError(_)) ->
                              api.error(500, "INTERNAL", "Database error")
                          }
                      }
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn handle_attach_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case parse_ids(rule_id, template_id) {
        Error(resp) -> resp
        Ok(#(rule_id, template_id)) -> {
          let auth.Ctx(db: db, ..) = ctx

          case rules_db.get_rule(db, rule_id) {
            Ok(rule) ->
              case workflow_from_rule(db, rule) {
                Error(resp) -> resp
                Ok(workflow) ->
                  case
                    authorization.require_project_manager_simple(
                      db,
                      user,
                      workflow.org_id,
                      workflow.project_id,
                    )
                  {
                    Error(resp) -> resp
                    Ok(Nil) ->
                      case validate_template_scope(db, workflow, template_id) {
                        Error(resp) -> resp
                        Ok(Nil) ->
                          attach_rule_template(req, ctx, rule_id, template_id)
                      }
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

fn handle_detach_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case parse_ids(rule_id, template_id) {
        Error(resp) -> resp
        Ok(#(rule_id, template_id)) -> {
          let auth.Ctx(db: db, ..) = ctx

          case rules_db.get_rule(db, rule_id) {
            Ok(rule) ->
              case workflow_from_rule(db, rule) {
                Error(resp) -> resp
                Ok(workflow) ->
                  case
                    authorization.require_project_manager_simple(
                      db,
                      user,
                      workflow.org_id,
                      workflow.project_id,
                    )
                  {
                    Error(resp) -> resp
                    Ok(Nil) ->
                      detach_rule_template(req, ctx, rule_id, template_id)
                  }
              }

            Error(_) -> api.error(404, "NOT_FOUND", "Not found")
          }
        }
      }
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

fn create_rule(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use name <- decode.field("name", decode.string)
        use goal <- decode.optional_field("goal", "", decode.string)
        use resource_type <- decode.field("resource_type", decode.string)
        use task_type_id <- decode.optional_field(
          "task_type_id",
          -1,
          decode.int,
        )
        use to_state <- decode.field("to_state", decode.string)
        use active <- decode.optional_field("active", False, decode.bool)
        decode.success(#(
          name,
          goal,
          resource_type,
          task_type_id,
          to_state,
          active,
        ))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(name, goal, resource_type, task_type_id, to_state, active)) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            rules_db.create_rule(
              db,
              workflow_id,
              name,
              goal,
              resource_type,
              task_type_id,
              to_state,
              active,
            )
          {
            Ok(rule) -> api.ok(json.object([#("rule", rule_json(rule))]))
            Error(rules_db.CreateInvalidResourceType) ->
              api.error(422, "VALIDATION_ERROR", "Invalid resource_type")
            Error(rules_db.CreateInvalidTaskType) ->
              api.error(422, "VALIDATION_ERROR", "Invalid task_type_id")
            Error(rules_db.CreateInvalidWorkflow) ->
              api.error(404, "NOT_FOUND", "Workflow not found")
            Error(rules_db.CreateDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn update_rule(req: wisp.Request, ctx: auth.Ctx, rule_id: Int) -> wisp.Response {
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
        use goal <- decode.optional_field(
          "goal",
          None,
          decode.optional(decode.string),
        )
        use resource_type <- decode.optional_field(
          "resource_type",
          None,
          decode.optional(decode.string),
        )
        use task_type_id <- decode.optional_field(
          "task_type_id",
          None,
          decode.optional(decode.int),
        )
        use to_state <- decode.optional_field(
          "to_state",
          None,
          decode.optional(decode.string),
        )
        use active <- decode.optional_field(
          "active",
          None,
          decode.optional(decode.int),
        )
        decode.success(#(
          name,
          goal,
          resource_type,
          task_type_id,
          to_state,
          active,
        ))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(name, goal, resource_type, task_type_id, to_state, active)) -> {
          let auth.Ctx(db: db, ..) = ctx

          let active_value = case active {
            None -> None
            Some(-1) -> None
            Some(0) -> Some(False)
            Some(_) -> Some(True)
          }

          let resource_type_value = case resource_type {
            Some("__unset__") -> None
            _ -> resource_type
          }
          let to_state_value = case to_state {
            Some("__unset__") -> None
            _ -> to_state
          }
          let task_type_value = case task_type_id {
            Some(-1) -> None
            _ -> task_type_id
          }

          case
            rules_db.update_rule(
              db,
              rule_id,
              name,
              goal,
              resource_type_value,
              task_type_value,
              to_state_value,
              active_value,
            )
          {
            Ok(rule) -> api.ok(json.object([#("rule", rule_json(rule))]))
            Error(rules_db.UpdateNotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(rules_db.UpdateInvalidResourceType) ->
              api.error(422, "VALIDATION_ERROR", "Invalid resource_type")
            Error(rules_db.UpdateInvalidTaskType) ->
              api.error(422, "VALIDATION_ERROR", "Invalid task_type_id")
            Error(rules_db.UpdateDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn attach_rule_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: Int,
  template_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use execution_order <- decode.optional_field(
          "execution_order",
          0,
          decode.int,
        )
        decode.success(execution_order)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(execution_order) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            rules_db.attach_template(db, rule_id, template_id, execution_order)
          {
            Ok(Nil) ->
              case rules_db.list_rule_templates(db, rule_id) {
                Ok(templates) ->
                  api.ok(
                    json.object([
                      #("templates", json.array(templates, of: template_json)),
                    ]),
                  )
                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }
            Error(rules_db.AttachNotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(rules_db.AttachDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn detach_rule_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: Int,
  template_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      let auth.Ctx(db: db, ..) = ctx

      case rules_db.detach_template(db, rule_id, template_id) {
        Ok(Nil) -> api.no_content()
        Error(rules_db.DetachNotFound) ->
          api.error(404, "NOT_FOUND", "Not found")
        Error(rules_db.DetachDbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn parse_ids(
  rule_id: String,
  template_id: String,
) -> Result(#(Int, Int), wisp.Response) {
  case int.parse(rule_id) {
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
    Ok(rule_id) ->
      case int.parse(template_id) {
        Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
        Ok(template_id) -> Ok(#(rule_id, template_id))
      }
  }
}

fn workflow_from_rule(
  db: pog.Connection,
  rule: rules_db.Rule,
) -> Result(workflows_db.Workflow, wisp.Response) {
  let rules_db.Rule(workflow_id: workflow_id, ..) = rule

  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(workflow)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Workflow not found"))
  }
}

fn validate_template_scope(
  db: pog.Connection,
  workflow: workflows_db.Workflow,
  template_id: Int,
) -> Result(Nil, wisp.Response) {
  let workflows_db.Workflow(org_id: org_id, project_id: project_id, ..) =
    workflow

  case task_templates_db.get_template(db, template_id) {
    Ok(template) ->
      case template_org_matches(template, org_id, project_id) {
        True -> Ok(Nil)
        False ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid template scope"))
      }
    Error(task_templates_db.UpdateNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Template not found"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn template_org_matches(
  template: task_templates_db.TaskTemplate,
  workflow_org_id: Int,
  workflow_project_id: Int,
) -> Bool {
  let task_templates_db.TaskTemplate(org_id: org_id, project_id: project_id, ..) =
    template

  // Both workflows and templates are now project-scoped, so they must match
  org_id == workflow_org_id && project_id == workflow_project_id
}

/// Rule JSON without templates (for create/update responses where rule has no templates yet).
fn rule_json(rule: rules_db.Rule) -> json.Json {
  rule_json_with_templates(rule, [])
}

/// Story 4.10: Added templates parameter to include attached templates.
fn rule_json_with_templates(
  rule: rules_db.Rule,
  templates: List(rules_db.RuleTemplate),
) -> json.Json {
  let rules_db.Rule(
    id: id,
    workflow_id: workflow_id,
    name: name,
    goal: goal,
    target: target,
    active: active,
    created_at: created_at,
  ) = rule
  let resource_type = rules_target.resource_type(target)
  let task_type_id = rules_target.task_type_id(target)
  let to_state = rules_target.to_state_string(target)

  json.object([
    #("id", json.int(id)),
    #("workflow_id", json.int(workflow_id)),
    #("name", json.string(name)),
    #("goal", json_helpers.option_string_json(goal)),
    #("resource_type", json.string(resource_type)),
    #("task_type_id", json_helpers.option_int_json(task_type_id)),
    #("to_state", json.string(to_state)),
    #("active", json.bool(active)),
    #("created_at", json.string(created_at)),
    #("templates", json.array(templates, of: template_json)),
  ])
}

fn template_json(template: rules_db.RuleTemplate) -> json.Json {
  let rules_db.RuleTemplate(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    type_id: type_id,
    type_name: type_name,
    priority: priority,
    created_by: created_by,
    created_at: created_at,
    execution_order: execution_order,
  ) = template

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("project_id", json_helpers.option_int_json(project_id)),
    #("name", json.string(name)),
    #("description", json_helpers.option_string_json(description)),
    #("type_id", json.int(type_id)),
    #("type_name", json.string(type_name)),
    #("priority", json.int(priority)),
    #("created_by", json.int(created_by)),
    #("created_at", json.string(created_at)),
    #("execution_order", json.int(execution_order)),
  ])
}
