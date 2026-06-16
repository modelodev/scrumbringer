//// HTTP handlers for workflow rules CRUD and template associations.
////
//// ## Mission
////
//// Provide rule management endpoints for workflow automation.
////
//// ## Responsibilities
////
//// - Authorize project managers for rule operations
//// - Parse and validate rule payloads
//// - Delegate persistence to rule services
////
//// ## Non-responsibilities
////
//// - Rule persistence (see `services/rules_db.gleam`)
//// - Workflow persistence (see `services/workflows_db.gleam`)
////
//// ## Relations
////
//// - Uses `services/rules_db` and `services/workflows_db` for persistence
//// - Uses `http/authorization` for access control

import domain/workflow
import gleam/http
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/option as option_helpers
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/http/rules/payloads as rule_payloads
import scrumbringer_server/http/rules/presenters as rule_presenters
import scrumbringer_server/http/service_error_response
import scrumbringer_server/services/rules_db
import scrumbringer_server/services/service_error
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/task_templates_db
import scrumbringer_server/services/workflows_db
import wisp

/// Handle /api/workflows/:workflow_id/rules requests.
/// Example: handle_workflow_rules(req, ctx, workflow_id)
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

/// Handle /api/rules/:rule_id requests.
/// Example: handle_rule(req, ctx, rule_id)
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

/// Handle /api/rules/:rule_id/templates/:template_id requests.
/// Example: handle_rule_template(req, ctx, rule_id, template_id)
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
  response_from_result(list_rules(req, ctx, workflow_id))
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case require_create_rule_access(req, ctx, workflow_id) {
    Error(resp) -> resp
    Ok(#(workflow, db)) ->
      json_payload.with_response(req, decode_create_payload, fn(payload) {
        response_from_result(create_rule_flow(workflow, db, payload))
      })
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case require_update_rule_access(req, ctx, rule_id) {
    Error(resp) -> resp
    Ok(#(rule, db)) ->
      json_payload.with_response(req, decode_update_payload, fn(payload) {
        response_from_result(update_rule_flow(rule, db, payload))
      })
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  response_from_result(delete_rule_flow(req, ctx, rule_id))
}

fn handle_attach_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
  template_id: String,
) -> wisp.Response {
  case require_attach_template_access(req, ctx, rule_id, template_id) {
    Error(resp) -> resp
    Ok(#(rule, db, template_id)) ->
      json_payload.with_response(
        req,
        decode_execution_order,
        fn(execution_order) {
          response_from_result(attach_template_flow(
            rule,
            db,
            template_id,
            execution_order,
          ))
        },
      )
  }
}

fn handle_detach_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
  template_id: String,
) -> wisp.Response {
  response_from_result(detach_template_flow(req, ctx, rule_id, template_id))
}

fn list_rules(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use #(_, workflow, db) <- result.try(load_workflow_access(
    req,
    ctx,
    workflow_id_str,
  ))
  use rules <- result.try(list_rules_for_workflow(db, workflow.id))
  use rules_with_templates <- result.try(list_rules_with_templates(db, rules))

  Ok(api.ok(rule_presenters.rules_response(rules_with_templates)))
}

fn response_from_result(
  result: Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case result {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn require_create_rule_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
) -> Result(#(workflows_db.WorkflowRecord, pog.Connection), wisp.Response) {
  use #(_, workflow, db) <- result.try(load_workflow_access(
    req,
    ctx,
    workflow_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(#(workflow, db))
}

fn create_rule_flow(
  workflow: workflows_db.WorkflowRecord,
  db: pog.Connection,
  payload: rule_payloads.CreatePayload,
) -> Result(wisp.Response, wisp.Response) {
  use task_type <- result.try(normalize_task_type_create(payload.task_type_id))
  use target <- result.try(parse_rule_target(
    payload.resource_type,
    task_type,
    payload.to_state,
  ))

  case
    rules_db.create_rule(
      db,
      workflow.id,
      payload.name,
      payload.goal,
      target,
      payload.active,
    )
  {
    Ok(rule) -> Ok(api.ok(rule_presenters.rule_response(rule)))
    Error(error) -> Error(create_rule_error_response(error))
  }
}

fn require_update_rule_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
) -> Result(#(rules_db.RuleRecord, pog.Connection), wisp.Response) {
  use #(rule, _workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(#(rule, db))
}

fn update_rule_flow(
  rule: rules_db.RuleRecord,
  db: pog.Connection,
  payload: rule_payloads.UpdatePayload,
) -> Result(wisp.Response, wisp.Response) {
  use target_value <- result.try(resolve_update_target(
    rule.target,
    payload.resource_type,
    payload.task_type_id,
    payload.to_state,
  ))

  case
    rules_db.update_rule(
      db,
      rule.id,
      payload.name,
      payload.goal,
      target_value,
      payload.active,
    )
  {
    Ok(rule) -> Ok(api.ok(rule_presenters.rule_response(rule)))
    Error(error) -> Error(rule_write_error_response(error))
  }
}

fn delete_rule_flow(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use #(rule, _workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(delete_rule_db(db, rule.id))
  Ok(api.no_content())
}

fn require_attach_template_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
  template_id_str: String,
) -> Result(#(rules_db.RuleRecord, pog.Connection, Int), wisp.Response) {
  use #(rule, workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use template_id <- result.try(api.parse_id(template_id_str))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(validate_template_scope(db, workflow, template_id))
  Ok(#(rule, db, template_id))
}

fn attach_template_flow(
  rule: rules_db.RuleRecord,
  db: pog.Connection,
  template_id: Int,
  execution_order: Int,
) -> Result(wisp.Response, wisp.Response) {
  use templates <- result.try(attach_rule_template_db(
    db,
    rule.id,
    template_id,
    execution_order,
  ))

  Ok(api.ok(rule_presenters.templates_response(templates)))
}

fn detach_template_flow(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
  template_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use #(rule, _workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use template_id <- result.try(api.parse_id(template_id_str))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(detach_rule_template_db(db, rule.id, template_id))
  Ok(api.no_content())
}

fn load_workflow_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
) -> Result(
  #(StoredUser, workflows_db.WorkflowRecord, pog.Connection),
  wisp.Response,
) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use workflow_id <- result.try(api.parse_id(workflow_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use workflow <- result.try(get_workflow(db, workflow_id))
  use _ <- result.try(require_project_manager(db, user, workflow))
  Ok(#(user, workflow, db))
}

fn load_rule_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
) -> Result(
  #(rules_db.RuleRecord, workflows_db.WorkflowRecord, pog.Connection),
  wisp.Response,
) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use rule_id <- result.try(api.parse_id(rule_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use rule <- result.try(get_rule(db, rule_id))
  use workflow <- result.try(workflow_from_rule(db, rule))
  use _ <- result.try(require_project_manager(db, user, workflow))
  Ok(#(rule, workflow, db))
}

fn require_project_manager(
  db: pog.Connection,
  user: StoredUser,
  workflow: workflows_db.WorkflowRecord,
) -> Result(Nil, wisp.Response) {
  authorization.require_project_manager_simple(
    db,
    user,
    workflow.org_id,
    workflow.project_id,
  )
}

fn get_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(workflows_db.WorkflowRecord, wisp.Response) {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(workflow)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn get_rule(
  db: pog.Connection,
  rule_id: Int,
) -> Result(rules_db.RuleRecord, wisp.Response) {
  case rules_db.get_rule(db, rule_id) {
    Ok(rule) -> Ok(rule)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn list_rules_for_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(List(rules_db.RuleRecord), wisp.Response) {
  case rules_db.list_rules_for_workflow(db, workflow_id) {
    Ok(rules) -> Ok(rules)
    Error(_) -> Error(database_error_response())
  }
}

fn list_rules_with_templates(
  db: pog.Connection,
  rules: List(rules_db.RuleRecord),
) {
  list.try_map(rules, fn(rule) {
    case rules_db.list_rule_templates(db, rule.id) {
      Ok(templates) -> Ok(rule_presenters.rule_with_templates(rule, templates))
      Error(error) -> Error(service_error_response.to_database_response(error))
    }
  })
}

fn decode_create_payload(
  data,
) -> Result(rule_payloads.CreatePayload, wisp.Response) {
  rule_payloads.decode_create(data)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn decode_update_payload(
  data,
) -> Result(rule_payloads.UpdatePayload, wisp.Response) {
  rule_payloads.decode_update(data)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn decode_execution_order(data) -> Result(Int, wisp.Response) {
  rule_payloads.decode_execution_order(data)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn normalize_task_type_create(
  task_type_id: Option(Int),
) -> Result(Option(Int), wisp.Response) {
  case task_type_id {
    Some(value) if value <= 0 ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid task_type_id"))
    _ -> Ok(task_type_id)
  }
}

fn normalize_task_type_patch(
  task_type_id: Option(Int),
) -> Result(Option(Int), wisp.Response) {
  case task_type_id {
    Some(value) if value <= 0 -> Ok(None)
    _ -> Ok(task_type_id)
  }
}

fn resolve_update_target(
  current: workflow.RuleTarget,
  resource_type: Option(String),
  task_type_id: Option(Int),
  to_state: Option(String),
) -> Result(Option(workflow.RuleTarget), wisp.Response) {
  case resource_type, task_type_id, to_state {
    None, None, None -> Ok(None)
    _, _, _ -> {
      let resource_type_value =
        option_helpers.option_to_value(
          resource_type,
          workflow.rule_target_resource_type(current),
        )
      use task_type_value <- result.try(resolve_update_task_type(
        current,
        resource_type_value,
        task_type_id,
      ))
      let to_state_value =
        option_helpers.option_to_value(
          to_state,
          workflow.rule_target_to_state_string(current),
        )
      use target <- result.try(parse_rule_target(
        resource_type_value,
        task_type_value,
        to_state_value,
      ))
      Ok(Some(target))
    }
  }
}

fn resolve_update_task_type(
  current: workflow.RuleTarget,
  resource_type: String,
  task_type_id: Option(Int),
) -> Result(Option(Int), wisp.Response) {
  case task_type_id {
    Some(_) -> normalize_task_type_patch(task_type_id)
    None ->
      case resource_type {
        "task" -> Ok(workflow.rule_target_task_type_id(current))
        _ -> Ok(None)
      }
  }
}

fn parse_rule_target(
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
) -> Result(workflow.RuleTarget, wisp.Response) {
  case workflow.parse_rule_target(resource_type, task_type_id, to_state) {
    Ok(target) -> Ok(target)
    Error(error) -> Error(rule_target_error_response(error))
  }
}

fn rule_target_error_response(
  error: workflow.RuleTargetValidationError,
) -> wisp.Response {
  case error {
    workflow.UnknownRuleResourceType(_) ->
      api.error(422, "VALIDATION_ERROR", "Invalid resource_type")
    workflow.CardRuleCannotHaveTaskType ->
      api.error(422, "VALIDATION_ERROR", "Invalid task_type_id")
    workflow.InvalidTaskRuleState(_) ->
      api.error(422, "VALIDATION_ERROR", "Invalid task to_state")
    workflow.InvalidCardRuleState(_) ->
      api.error(422, "VALIDATION_ERROR", "Invalid card to_state")
  }
}

fn delete_rule_db(
  db: pog.Connection,
  rule_id: Int,
) -> Result(Nil, wisp.Response) {
  case rules_db.delete_rule(db, rule_id) {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(rule_write_error_response(error))
  }
}

fn attach_rule_template_db(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
) -> Result(List(workflow.RuleTemplate), wisp.Response) {
  case rules_db.attach_template(db, rule_id, template_id, execution_order) {
    Ok(Nil) ->
      case rules_db.list_rule_templates(db, rule_id) {
        Ok(templates) -> Ok(templates)
        Error(error) ->
          Error(service_error_response.to_database_response(error))
      }
    Error(error) -> Error(rule_write_error_response(error))
  }
}

fn detach_rule_template_db(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
) -> Result(Nil, wisp.Response) {
  case rules_db.detach_template(db, rule_id, template_id) {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(rule_write_error_response(error))
  }
}

fn workflow_from_rule(
  db: pog.Connection,
  rule: rules_db.RuleRecord,
) -> Result(workflows_db.WorkflowRecord, wisp.Response) {
  let rules_db.RuleRecord(workflow_id: workflow_id, ..) = rule

  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(workflow)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Workflow not found"))
  }
}

fn validate_template_scope(
  db: pog.Connection,
  workflow: workflows_db.WorkflowRecord,
  template_id: Int,
) -> Result(Nil, wisp.Response) {
  let workflows_db.WorkflowRecord(org_id: org_id, project_id: project_id, ..) =
    workflow

  case task_templates_db.get_template(db, template_id) {
    Ok(template) ->
      case template_org_matches(template, org_id, project_id) {
        True -> Ok(Nil)
        False ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid template scope"))
      }
    Error(error) -> Error(template_scope_error_response(error))
  }
}

fn create_rule_error_response(
  error: service_error.ServiceError,
) -> wisp.Response {
  case error {
    service_error.InvalidReference("workflow_id") ->
      api.error(404, "NOT_FOUND", "Workflow not found")
    _ -> rule_write_error_response(error)
  }
}

fn template_scope_error_response(
  error: service_error.ServiceError,
) -> wisp.Response {
  case error {
    service_error.NotFound -> api.error(404, "NOT_FOUND", "Template not found")
    service_error.InvalidReference(_) ->
      api.error(422, "VALIDATION_ERROR", "Invalid template scope")
    _ -> rule_write_error_response(error)
  }
}

fn rule_write_error_response(error: service_error.ServiceError) -> wisp.Response {
  case error {
    service_error.InvalidReference("resource_type") ->
      api.error(422, "VALIDATION_ERROR", "Invalid resource_type")
    service_error.InvalidReference("task_type_id") ->
      api.error(422, "VALIDATION_ERROR", "Invalid task_type_id")
    _ -> service_error_response.to_response(error)
  }
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
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
