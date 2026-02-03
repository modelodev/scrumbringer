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

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/json as json_helpers
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/services/rules_db
import scrumbringer_server/services/rules_target
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

  case list_rules(req, ctx, workflow_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  // Justified nested case: unwrap Result<Response, Response> into a Response.
  case create_rule_flow(req, ctx, workflow_id, data) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  // Justified nested case: unwrap Result<Response, Response> into a Response.
  case update_rule_flow(req, ctx, rule_id, data) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
) -> wisp.Response {
  case delete_rule_flow(req, ctx, rule_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_attach_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
  template_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  // Justified nested case: unwrap Result<Response, Response> into a Response.
  case attach_template_flow(req, ctx, rule_id, template_id, data) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_detach_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id: String,
  template_id: String,
) -> wisp.Response {
  case detach_template_flow(req, ctx, rule_id, template_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

type CreatePayload {
  CreatePayload(
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Option(Int),
    to_state: String,
    active: Bool,
  )
}

type UpdatePayload {
  UpdatePayload(
    name: Option(String),
    goal: Option(String),
    resource_type: Option(String),
    task_type_id: Option(Int),
    to_state: Option(String),
    active: Option(Int),
  )
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

  let rules_with_templates =
    list.map(rules, fn(rule) {
      let templates = case rules_db.list_rule_templates(db, rule.id) {
        Ok(t) -> t
        Error(_) -> []
      }
      rule_json_with_templates(rule, templates)
    })

  Ok(
    api.ok(
      json.object([
        #("rules", json.preprocessed_array(rules_with_templates)),
      ]),
    ),
  )
}

fn create_rule_flow(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use #(_, workflow, db) <- result.try(load_workflow_access(
    req,
    ctx,
    workflow_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  use payload <- result.try(decode_create_payload(data))
  use task_type_param <- result.try(normalize_task_type_create(
    payload.task_type_id,
  ))

  case
    rules_db.create_rule(
      db,
      workflow.id,
      payload.name,
      payload.goal,
      payload.resource_type,
      task_type_param,
      payload.to_state,
      payload.active,
    )
  {
    Ok(rule) -> Ok(api.ok(json.object([#("rule", rule_json(rule))])))
    Error(service_error.InvalidReference("resource_type")) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid resource_type"))
    Error(service_error.InvalidReference("task_type_id")) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid task_type_id"))
    Error(service_error.InvalidReference("workflow_id")) ->
      Error(api.error(404, "NOT_FOUND", "Workflow not found"))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
  }
}

fn update_rule_flow(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use #(rule, _workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  use payload <- result.try(decode_update_payload(data))
  use active_value <- result.try(normalize_active(payload.active))
  use task_type_value <- result.try(normalize_task_type_update(
    payload.task_type_id,
  ))

  case
    rules_db.update_rule(
      db,
      rule.id,
      payload.name,
      payload.goal,
      payload.resource_type,
      task_type_value,
      payload.to_state,
      active_value,
    )
  {
    Ok(rule) -> Ok(api.ok(json.object([#("rule", rule_json(rule))])))
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.InvalidReference("resource_type")) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid resource_type"))
    Error(service_error.InvalidReference("task_type_id")) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid task_type_id"))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
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

fn attach_template_flow(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
  template_id_str: String,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use #(rule, workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use template_id <- result.try(parse_id(template_id_str))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(validate_template_scope(db, workflow, template_id))
  use execution_order <- result.try(decode_execution_order(data))
  use templates <- result.try(attach_rule_template_db(
    db,
    rule.id,
    template_id,
    execution_order,
  ))

  Ok(
    api.ok(
      json.object([
        #("templates", json.array(templates, of: template_json)),
      ]),
    ),
  )
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
  use template_id <- result.try(parse_id(template_id_str))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(detach_rule_template_db(db, rule.id, template_id))
  Ok(api.no_content())
}

fn load_workflow_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
) -> Result(#(StoredUser, workflows_db.Workflow, pog.Connection), wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use workflow_id <- result.try(parse_id(workflow_id_str))
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
  #(rules_db.Rule, workflows_db.Workflow, pog.Connection),
  wisp.Response,
) {
  use user <- result.try(require_current_user(req, ctx))
  use rule_id <- result.try(parse_id(rule_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use rule <- result.try(get_rule(db, rule_id))
  use workflow <- result.try(workflow_from_rule(db, rule))
  use _ <- result.try(require_project_manager(db, user, workflow))
  Ok(#(rule, workflow, db))
}

fn require_current_user(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  case auth.require_current_user(req, ctx) {
    Ok(user) -> Ok(user)
    Error(_) ->
      Error(api.error(401, "AUTH_REQUIRED", "Authentication required"))
  }
}

fn require_project_manager(
  db: pog.Connection,
  user: StoredUser,
  workflow: workflows_db.Workflow,
) -> Result(Nil, wisp.Response) {
  case
    authorization.require_project_manager_simple(
      db,
      user,
      workflow.org_id,
      workflow.project_id,
    )
  {
    Ok(Nil) -> Ok(Nil)
    Error(resp) -> Error(resp)
  }
}

fn parse_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn get_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(workflows_db.Workflow, wisp.Response) {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(workflow)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn get_rule(
  db: pog.Connection,
  rule_id: Int,
) -> Result(rules_db.Rule, wisp.Response) {
  case rules_db.get_rule(db, rule_id) {
    Ok(rule) -> Ok(rule)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn list_rules_for_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(List(rules_db.Rule), wisp.Response) {
  case rules_db.list_rules_for_workflow(db, workflow_id) {
    Ok(rules) -> Ok(rules)
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn decode_create_payload(
  data: dynamic.Dynamic,
) -> Result(CreatePayload, wisp.Response) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use goal <- decode.optional_field("goal", "", decode.string)
    use resource_type <- decode.field("resource_type", decode.string)
    use task_type_id <- decode.optional_field(
      "task_type_id",
      None,
      decode.optional(decode.int),
    )
    use to_state <- decode.field("to_state", decode.string)
    use active <- decode.optional_field("active", False, decode.bool)
    decode.success(CreatePayload(
      name: name,
      goal: goal,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
      active: active,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn decode_update_payload(
  data: dynamic.Dynamic,
) -> Result(UpdatePayload, wisp.Response) {
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
    decode.success(UpdatePayload(
      name: name,
      goal: goal,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
      active: active,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn decode_execution_order(data: dynamic.Dynamic) -> Result(Int, wisp.Response) {
  let decoder = {
    use execution_order <- decode.optional_field(
      "execution_order",
      0,
      decode.int,
    )
    decode.success(execution_order)
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn normalize_task_type_create(
  task_type_id: Option(Int),
) -> Result(Int, wisp.Response) {
  case task_type_id {
    Some(value) if value <= 0 ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid task_type_id"))
    Some(value) -> Ok(value)
    None -> Ok(0)
  }
}

fn normalize_task_type_update(
  task_type_id: Option(Int),
) -> Result(Option(Int), wisp.Response) {
  case task_type_id {
    Some(value) if value <= 0 ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid task_type_id"))
    _ -> Ok(task_type_id)
  }
}

fn normalize_active(active: Option(Int)) -> Result(Option(Bool), wisp.Response) {
  case active {
    None -> Ok(None)
    Some(0) -> Ok(Some(False))
    Some(1) -> Ok(Some(True))
    Some(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid active"))
  }
}

fn delete_rule_db(
  db: pog.Connection,
  rule_id: Int,
) -> Result(Nil, wisp.Response) {
  case rules_db.delete_rule(db, rule_id) {
    Ok(Nil) -> Ok(Nil)
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
  }
}

// Justification: nested case improves clarity for branching logic.
fn attach_rule_template_db(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
) -> Result(List(rules_db.RuleTemplate), wisp.Response) {
  case rules_db.attach_template(db, rule_id, template_id, execution_order) {
    Ok(Nil) ->
      case rules_db.list_rule_templates(db, rule_id) {
        Ok(templates) -> Ok(templates)
        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
  }
}

fn detach_rule_template_db(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
) -> Result(Nil, wisp.Response) {
  case rules_db.detach_template(db, rule_id, template_id) {
    Ok(Nil) -> Ok(Nil)
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
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

// Justification: nested case improves clarity for branching logic.
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
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Template not found"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid template scope"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
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
