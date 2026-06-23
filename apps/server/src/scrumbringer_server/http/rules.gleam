//// HTTP handlers for workflow rules CRUD.
////
//// ## Mission
////
//// Provide rule management endpoints for workflow automation.
////
//// ## Responsibilities
////
//// - Authorize project managers for rule operations
//// - Parse and validate rule payloads
//// - Delegate repository to rule use_case
////
//// ## Non-responsibilities
////
//// - Rule repository (see `use_case/rules_db.gleam`)
//// - Workflow repository (see `use_case/workflows_db.gleam`)
////
//// ## Relations
////
//// - Uses `use_case/rules_db` and `use_case/workflows_db` for repository
//// - Uses `http/authorization` for access control

import domain/automation
import domain/workflow
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/http/rules/payloads as rule_payloads
import scrumbringer_server/http/rules/presenters as rule_presenters
import scrumbringer_server/http/service_error_response
import scrumbringer_server/use_case/automation_config_audit_db as config_audit
import scrumbringer_server/use_case/rules_db
import scrumbringer_server/use_case/service_error
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/task_templates_db
import scrumbringer_server/use_case/workflows_db
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
    Ok(#(user, workflow, db)) ->
      json_payload.with_response(req, decode_create_payload, fn(payload) {
        response_from_result(create_rule_flow(user, workflow, db, payload))
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
    Ok(#(user, rule, workflow, db)) ->
      json_payload.with_response(req, decode_update_payload, fn(payload) {
        response_from_result(update_rule_flow(user, rule, workflow, db, payload))
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
) -> Result(
  #(StoredUser, workflows_db.WorkflowRecord, pog.Connection),
  wisp.Response,
) {
  use #(user, workflow, db) <- result.try(load_workflow_access(
    req,
    ctx,
    workflow_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(#(user, workflow, db))
}

fn create_rule_flow(
  user: StoredUser,
  workflow: workflows_db.WorkflowRecord,
  db: pog.Connection,
  payload: rule_payloads.CreatePayload,
) -> Result(wisp.Response, wisp.Response) {
  let template_id = automation.action_template_id(payload.action)
  use _ <- result.try(validate_rule_trigger_scope(db, workflow, payload.trigger))
  use _ <- result.try(validate_required_rule_template(
    db,
    workflow,
    template_id,
    payload.trigger,
  ))

  run_config_transaction(db, fn(tx) {
    use rule <- result.try(
      rules_db.create_rule(
        tx,
        workflow.id,
        payload.name,
        payload.goal,
        payload.trigger,
        payload.action,
        payload.status,
      )
      |> result.map_error(create_rule_error_response),
    )
    use template <- result.try(sync_rule_template(
      tx,
      rule.id,
      Some(template_id),
    ))
    use _ <- result.try(record_config_change(
      tx,
      user,
      workflow.project_id,
      config_audit.Rule,
      rule.id,
      config_audit.Created,
      json.object([#("name", json.string(rule.name))]),
    ))
    Ok(api.ok(rule_presenters.rule_response_with_template(rule, template)))
  })
}

fn require_update_rule_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
) -> Result(
  #(
    StoredUser,
    rules_db.RuleRecord,
    workflows_db.WorkflowRecord,
    pog.Connection,
  ),
  wisp.Response,
) {
  use #(user, rule, workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(#(user, rule, workflow, db))
}

fn update_rule_flow(
  user: StoredUser,
  rule: rules_db.RuleRecord,
  workflow: workflows_db.WorkflowRecord,
  db: pog.Connection,
  payload: rule_payloads.UpdatePayload,
) -> Result(wisp.Response, wisp.Response) {
  let template_id = option_action_template_id(payload.action)
  let trigger = option_value(payload.trigger, rule.trigger)
  use _ <- result.try(validate_rule_trigger_scope(db, workflow, trigger))
  use _ <- result.try(validate_update_rule_template(
    db,
    workflow,
    rule.id,
    template_id,
    trigger,
  ))

  run_config_transaction(db, fn(tx) {
    use updated_rule <- result.try(
      rules_db.update_rule(
        tx,
        rule.id,
        payload.name,
        payload.goal,
        payload.trigger,
        payload.action,
        payload.status,
      )
      |> result.map_error(rule_write_error_response),
    )
    use template <- result.try(sync_rule_template(tx, rule.id, template_id))
    use _ <- result.try(record_config_change(
      tx,
      user,
      workflow.project_id,
      config_audit.Rule,
      rule.id,
      rule_update_change_type(payload.status),
      json.object([#("name", json.string(updated_rule.name))]),
    ))
    Ok(
      api.ok(rule_presenters.rule_response_with_template(updated_rule, template)),
    )
  })
}

fn delete_rule_flow(
  req: wisp.Request,
  ctx: auth.Ctx,
  rule_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use #(user, rule, workflow, db) <- result.try(load_rule_access(
    req,
    ctx,
    rule_id_str,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(delete_rule_db(db, user, rule, workflow))
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
  #(
    StoredUser,
    rules_db.RuleRecord,
    workflows_db.WorkflowRecord,
    pog.Connection,
  ),
  wisp.Response,
) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use rule_id <- result.try(api.parse_id(rule_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use rule <- result.try(get_rule(db, rule_id))
  use workflow <- result.try(workflow_from_rule(db, rule))
  use _ <- result.try(require_project_manager(db, user, workflow))
  Ok(#(user, rule, workflow, db))
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
    case rules_db.selected_rule_template(db, rule.id) {
      Ok(template) -> Ok(rule_presenters.rule_with_template(rule, template))
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

fn delete_rule_db(
  db: pog.Connection,
  user: StoredUser,
  rule: rules_db.RuleRecord,
  workflow: workflows_db.WorkflowRecord,
) -> Result(Nil, wisp.Response) {
  run_config_transaction(db, fn(tx) {
    use disposition <- result.try(
      rules_db.delete_rule_with_disposition(tx, rule.id)
      |> result.map_error(rule_write_error_response),
    )
    use _ <- result.try(record_config_change(
      tx,
      user,
      workflow.project_id,
      config_audit.Rule,
      rule.id,
      case disposition {
        rules_db.PhysicallyDeleted -> config_audit.Deleted
        rules_db.Archived -> config_audit.Archived
      },
      json.object([#("name", json.string(rule.name))]),
    ))
    Ok(Nil)
  })
}

fn option_action_template_id(
  action: Option(automation.AutomationAction),
) -> Option(Int) {
  case action {
    Some(action) -> Some(automation.action_template_id(action))
    None -> None
  }
}

fn option_value(value: Option(a), fallback: a) -> a {
  case value {
    Some(inner) -> inner
    None -> fallback
  }
}

fn validate_required_rule_template(
  db: pog.Connection,
  workflow: workflows_db.WorkflowRecord,
  template_id: Int,
  trigger: automation.AutomationTrigger,
) -> Result(Nil, wisp.Response) {
  case template_id {
    value if value <= 0 ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid template_id"))
    value -> validate_template_for_trigger(db, workflow, value, trigger)
  }
}

fn validate_update_rule_template(
  db: pog.Connection,
  workflow: workflows_db.WorkflowRecord,
  rule_id: Int,
  template_id: Option(Int),
  trigger: automation.AutomationTrigger,
) -> Result(Nil, wisp.Response) {
  case template_id {
    Some(value) -> validate_required_rule_template(db, workflow, value, trigger)
    None -> {
      use template <- result.try(list_rule_template_response(db, rule_id))
      case template {
        Some(template) ->
          validate_rule_template_variables(
            template.name,
            template.description,
            trigger,
          )
        None -> Error(api.error(422, "VALIDATION_ERROR", "Missing template_id"))
      }
    }
  }
}

fn sync_rule_template(
  db: pog.Connection,
  rule_id: Int,
  template_id: Option(Int),
) -> Result(Option(workflow.RuleTemplate), wisp.Response) {
  case template_id {
    None -> list_rule_template_response(db, rule_id)
    Some(value) -> select_rule_template_response(db, rule_id, value, 1)
  }
}

fn list_rule_template_response(
  db: pog.Connection,
  rule_id: Int,
) -> Result(Option(workflow.RuleTemplate), wisp.Response) {
  case rules_db.selected_rule_template(db, rule_id) {
    Ok(template) -> Ok(template)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn select_rule_template_response(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
) -> Result(Option(workflow.RuleTemplate), wisp.Response) {
  case rules_db.select_template(db, rule_id, template_id, execution_order) {
    Ok(Nil) -> list_rule_template_response(db, rule_id)
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

fn validate_rule_trigger_scope(
  db: pog.Connection,
  workflow: workflows_db.WorkflowRecord,
  trigger: automation.AutomationTrigger,
) -> Result(Nil, wisp.Response) {
  case trigger {
    automation.CardActivated(scope) | automation.CardClosed(scope) ->
      validate_card_scope_depth(db, workflow.project_id, scope)
    _ -> Ok(Nil)
  }
}

fn validate_card_scope_depth(
  db: pog.Connection,
  project_id: Int,
  scope: automation.CardAutomationScope,
) -> Result(Nil, wisp.Response) {
  case scope {
    automation.AnyCard -> Ok(Nil)
    automation.AtDepth(depth) ->
      validate_project_card_depth(
        db,
        project_id,
        automation.card_depth_to_int(depth),
      )
  }
}

fn validate_project_card_depth(
  db: pog.Connection,
  project_id: Int,
  depth: Int,
) -> Result(Nil, wisp.Response) {
  case project_card_depth_exists(db, project_id, depth) {
    Ok(True) -> Ok(Nil)
    Ok(False) ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Card level is no longer available",
      ))
    Error(_) -> Error(database_error_response())
  }
}

fn project_card_depth_exists(
  db: pog.Connection,
  project_id: Int,
  depth: Int,
) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  use returned <- result.try(
    pog.query(
      "select 1 from project_card_depth_names where project_id = $1 and depth = $2 limit 1",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(depth))
    |> pog.returning(decoder)
    |> pog.execute(db),
  )

  case returned.rows {
    [] -> Ok(False)
    _ -> Ok(True)
  }
}

fn validate_template_for_trigger(
  db: pog.Connection,
  workflow: workflows_db.WorkflowRecord,
  template_id: Int,
  trigger: automation.AutomationTrigger,
) -> Result(Nil, wisp.Response) {
  let workflows_db.WorkflowRecord(org_id: org_id, project_id: project_id, ..) =
    workflow

  case task_templates_db.get_template(db, template_id) {
    Ok(template) ->
      case template_org_matches(template, org_id, project_id) {
        True ->
          validate_rule_template_variables(
            template.name,
            template.description,
            trigger,
          )
        False ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid template scope"))
      }
    Error(error) -> Error(template_scope_error_response(error))
  }
}

fn validate_rule_template_variables(
  name: String,
  description: Option(String),
  trigger: automation.AutomationTrigger,
) -> Result(Nil, wisp.Response) {
  case
    automation.template_uses_unknown_variables(name, trigger)
    || description_uses_unknown_variables(description, trigger)
  {
    True ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Template variables are not available for this trigger",
      ))
    False -> Ok(Nil)
  }
}

fn description_uses_unknown_variables(
  description: Option(String),
  trigger: automation.AutomationTrigger,
) -> Bool {
  case description {
    Some(value) -> automation.template_uses_unknown_variables(value, trigger)
    None -> False
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
    service_error.InvalidReference("task_type_id") ->
      api.error(422, "VALIDATION_ERROR", "Invalid task_type_id")
    service_error.InvalidReference("template_id") ->
      api.error(422, "VALIDATION_ERROR", "Invalid template_id")
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

fn record_config_change(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
  entity_type: config_audit.EntityType,
  entity_id: Int,
  change_type: config_audit.ChangeType,
  payload: json.Json,
) -> Result(Nil, wisp.Response) {
  config_audit.insert(
    db,
    user.org_id,
    project_id,
    user.id,
    entity_type,
    entity_id,
    change_type,
    payload,
  )
  |> result.map_error(service_error_response.to_response)
}

fn rule_update_change_type(
  status: Option(automation.AutomationRuleStatus),
) -> config_audit.ChangeType {
  case status {
    Some(automation.Paused) -> config_audit.Paused
    Some(automation.Active) -> config_audit.Reactivated
    Some(automation.RequiresReview(_)) -> config_audit.Updated
    None -> config_audit.Updated
  }
}

fn run_config_transaction(
  db: pog.Connection,
  callback: fn(pog.Connection) -> Result(a, wisp.Response),
) -> Result(a, wisp.Response) {
  case pog.transaction(db, callback) {
    Ok(value) -> Ok(value)
    Error(pog.TransactionRolledBack(resp)) -> Error(resp)
    Error(pog.TransactionQueryError(_)) -> Error(database_error_response())
  }
}
