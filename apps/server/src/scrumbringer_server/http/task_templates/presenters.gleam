//// JSON presenters for task template endpoints.

import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/use_case/task_templates_db

pub fn templates_response(
  values: List(task_templates_db.TaskTemplate),
) -> json.Json {
  json.object([#("templates", json.array(values, of: template))])
}

/// Story 4.9 AC20: Added rules_count field.
pub fn template(template: task_templates_db.TaskTemplate) -> json.Json {
  let task_templates_db.TaskTemplate(
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
    rules_count: rules_count,
  ) = template

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("description", json_helpers.option_string_json(description)),
    #("type_id", json.int(type_id)),
    #("type_name", json.string(type_name)),
    #("priority", json.int(priority)),
    #("created_by", json.int(created_by)),
    #("created_at", json.string(created_at)),
    #("rules_count", json.int(rules_count)),
  ])
}

pub fn template_response(value: task_templates_db.TaskTemplate) -> json.Json {
  json.object([#("template", template(value))])
}
