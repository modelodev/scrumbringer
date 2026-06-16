//// JSON presenters for workflow endpoints.

import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/services/workflows_db

pub fn workflows_response(
  values: List(workflows_db.WorkflowRecord),
) -> json.Json {
  json.object([#("workflows", json.array(values, of: workflow))])
}

pub fn workflow(workflow: workflows_db.WorkflowRecord) -> json.Json {
  let workflows_db.WorkflowRecord(
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

pub fn workflow_response(value: workflows_db.WorkflowRecord) -> json.Json {
  json.object([#("workflow", workflow(value))])
}
