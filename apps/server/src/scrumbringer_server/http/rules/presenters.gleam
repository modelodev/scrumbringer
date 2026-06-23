//// JSON presenters for workflow rule endpoints.

import domain/workflow
import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/use_case/rules_db

pub fn rules_response(values: List(json.Json)) -> json.Json {
  json.object([#("rules", json.preprocessed_array(values))])
}

pub fn rule(rule: rules_db.RuleRecord) -> json.Json {
  rule_with_templates(rule, [])
}

pub fn rule_response(value: rules_db.RuleRecord) -> json.Json {
  json.object([#("rule", rule(value))])
}

pub fn rule_response_with_templates(
  rule: rules_db.RuleRecord,
  templates: List(workflow.RuleTemplate),
) -> json.Json {
  json.object([#("rule", rule_with_templates(rule, templates))])
}

pub fn rule_with_templates(
  rule: rules_db.RuleRecord,
  templates: List(workflow.RuleTemplate),
) -> json.Json {
  let rules_db.RuleRecord(
    id: id,
    workflow_id: workflow_id,
    name: name,
    goal: goal,
    target: target,
    active: active,
    created_at: created_at,
  ) = rule
  let resource_type = workflow.rule_target_resource_type(target)
  let task_type_id = workflow.rule_target_task_type_id(target)
  let to_state = workflow.rule_target_to_state_string(target)

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
    #("templates", json.array(templates, of: template)),
  ])
}

pub fn template(template: workflow.RuleTemplate) -> json.Json {
  let workflow.RuleTemplate(
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

pub fn templates_response(values: List(workflow.RuleTemplate)) -> json.Json {
  json.object([#("templates", json.array(values, of: template))])
}
