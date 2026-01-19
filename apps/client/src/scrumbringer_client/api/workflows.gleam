//// Workflows API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides workflow, rule, and task template API operations for automation
//// management in the admin interface.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}

import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow, Rule,
  RuleTemplate, TaskTemplate, Workflow,
}

// =============================================================================
// Decoders
// =============================================================================

fn workflow_decoder() -> decode.Decoder(Workflow) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", nullable_int())
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", nullable_string())
  use active <- decode.field("active", decode.bool)
  use rule_count <- decode.field("rule_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Workflow(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    active: active,
    rule_count: rule_count,
    created_by: created_by,
    created_at: created_at,
  ))
}

fn rule_decoder() -> decode.Decoder(Rule) {
  use id <- decode.field("id", decode.int)
  use workflow_id <- decode.field("workflow_id", decode.int)
  use name <- decode.field("name", decode.string)
  use goal <- decode.field("goal", nullable_string())
  use resource_type <- decode.field("resource_type", decode.string)
  use task_type_id <- decode.field("task_type_id", nullable_int())
  use to_state <- decode.field("to_state", decode.string)
  use active <- decode.field("active", decode.bool)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Rule(
    id: id,
    workflow_id: workflow_id,
    name: name,
    goal: goal,
    resource_type: resource_type,
    task_type_id: task_type_id,
    to_state: to_state,
    active: active,
    created_at: created_at,
  ))
}

fn task_template_decoder() -> decode.Decoder(TaskTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", nullable_int())
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", nullable_string())
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(TaskTemplate(
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
  ))
}

fn rule_template_decoder() -> decode.Decoder(RuleTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", nullable_int())
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", nullable_string())
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use execution_order <- decode.field("execution_order", decode.int)
  decode.success(RuleTemplate(
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
  ))
}

fn nullable_int() -> decode.Decoder(Option(Int)) {
  decode.optional(decode.int)
}

fn nullable_string() -> decode.Decoder(Option(String)) {
  decode.optional(decode.string)
}

// =============================================================================
// Public Payload Decoders (for testing)
// =============================================================================

/// Decoder for workflow wrapped in envelope.
pub fn workflow_payload_decoder() -> decode.Decoder(Workflow) {
  decode.field("workflow", workflow_decoder(), decode.success)
}

/// Decoder for list of workflows.
pub fn workflows_payload_decoder() -> decode.Decoder(List(Workflow)) {
  decode.field("workflows", decode.list(workflow_decoder()), decode.success)
}

/// Decoder for rule wrapped in envelope.
pub fn rule_payload_decoder() -> decode.Decoder(Rule) {
  decode.field("rule", rule_decoder(), decode.success)
}

/// Decoder for list of rules.
pub fn rules_payload_decoder() -> decode.Decoder(List(Rule)) {
  decode.field("rules", decode.list(rule_decoder()), decode.success)
}

/// Decoder for task template wrapped in envelope.
pub fn task_template_payload_decoder() -> decode.Decoder(TaskTemplate) {
  decode.field("task_template", task_template_decoder(), decode.success)
}

/// Decoder for list of task templates.
pub fn task_templates_payload_decoder() -> decode.Decoder(List(TaskTemplate)) {
  decode.field(
    "task_templates",
    decode.list(task_template_decoder()),
    decode.success,
  )
}

/// Decoder for list of rule templates.
pub fn rule_templates_payload_decoder() -> decode.Decoder(List(RuleTemplate)) {
  decode.field(
    "templates",
    decode.list(rule_template_decoder()),
    decode.success,
  )
}

// =============================================================================
// Workflow API
// =============================================================================

/// List org-scoped workflows.
pub fn list_org_workflows(
  to_msg: fn(ApiResult(List(Workflow))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("workflows", decode.list(workflow_decoder()), decode.success)
  core.request("GET", "/api/v1/workflows", None, decoder, to_msg)
}

/// List project-scoped workflows.
pub fn list_project_workflows(
  project_id: Int,
  to_msg: fn(ApiResult(List(Workflow))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("workflows", decode.list(workflow_decoder()), decode.success)
  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
    None,
    decoder,
    to_msg,
  )
}

/// Create org-scoped workflow.
pub fn create_org_workflow(
  name: String,
  description: String,
  active: Bool,
  to_msg: fn(ApiResult(Workflow)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("active", json.bool(active)),
    ])
  let decoder = decode.field("workflow", workflow_decoder(), decode.success)
  core.request("POST", "/api/v1/workflows", Some(body), decoder, to_msg)
}

/// Create project-scoped workflow.
pub fn create_project_workflow(
  project_id: Int,
  name: String,
  description: String,
  active: Bool,
  to_msg: fn(ApiResult(Workflow)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("active", json.bool(active)),
    ])
  let decoder = decode.field("workflow", workflow_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
    Some(body),
    decoder,
    to_msg,
  )
}

/// Update workflow.
pub fn update_workflow(
  workflow_id: Int,
  name: String,
  description: String,
  active: Bool,
  to_msg: fn(ApiResult(Workflow)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("active", json.int(case active {
        True -> 1
        False -> 0
      })),
    ])
  let decoder = decode.field("workflow", workflow_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/workflows/" <> int.to_string(workflow_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Delete workflow.
pub fn delete_workflow(
  workflow_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil("DELETE",
    "/api/v1/workflows/" <> int.to_string(workflow_id),
    None,
    to_msg,
  )
}

// =============================================================================
// Rule API
// =============================================================================

/// List rules for a workflow.
pub fn list_rules(
  workflow_id: Int,
  to_msg: fn(ApiResult(List(Rule))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("rules", decode.list(rule_decoder()), decode.success)
  core.request(
    "GET",
    "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
    None,
    decoder,
    to_msg,
  )
}

/// Create rule in a workflow.
pub fn create_rule(
  workflow_id: Int,
  name: String,
  goal: String,
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
  active: Bool,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #("resource_type", json.string(resource_type)),
      #("task_type_id", case task_type_id {
        None -> json.null()
        Some(id) -> json.int(id)
      }),
      #("to_state", json.string(to_state)),
      #("active", json.bool(active)),
    ])
  let decoder = decode.field("rule", rule_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
    Some(body),
    decoder,
    to_msg,
  )
}

/// Update rule.
pub fn update_rule(
  rule_id: Int,
  name: String,
  goal: String,
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
  active: Bool,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #("resource_type", json.string(resource_type)),
      #("task_type_id", case task_type_id {
        None -> json.int(-1)
        Some(id) -> json.int(id)
      }),
      #("to_state", json.string(to_state)),
      #("active", json.int(case active {
        True -> 1
        False -> 0
      })),
    ])
  let decoder = decode.field("rule", rule_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/rules/" <> int.to_string(rule_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Delete rule.
pub fn delete_rule(
  rule_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil("DELETE", "/api/v1/rules/" <> int.to_string(rule_id), None, to_msg)
}

/// Attach template to rule.
pub fn attach_template(
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
  to_msg: fn(ApiResult(List(RuleTemplate))) -> msg,
) -> Effect(msg) {
  let body = json.object([#("execution_order", json.int(execution_order))])
  let decoder =
    decode.field(
      "templates",
      decode.list(rule_template_decoder()),
      decode.success,
    )
  core.request(
    "POST",
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/templates/"
      <> int.to_string(template_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Detach template from rule.
pub fn detach_template(
  rule_id: Int,
  template_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/templates/"
      <> int.to_string(template_id),
    None,
    to_msg,
  )
}

// =============================================================================
// TaskTemplate API
// =============================================================================

/// List org-scoped task templates.
pub fn list_org_templates(
  to_msg: fn(ApiResult(List(TaskTemplate))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "task_templates",
      decode.list(task_template_decoder()),
      decode.success,
    )
  core.request("GET", "/api/v1/task-templates", None, decoder, to_msg)
}

/// List project-scoped task templates.
pub fn list_project_templates(
  project_id: Int,
  to_msg: fn(ApiResult(List(TaskTemplate))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "task_templates",
      decode.list(task_template_decoder()),
      decode.success,
    )
  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
    None,
    decoder,
    to_msg,
  )
}

/// Create org-scoped task template.
pub fn create_org_template(
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  to_msg: fn(ApiResult(TaskTemplate)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("type_id", json.int(type_id)),
      #("priority", json.int(priority)),
    ])
  let decoder =
    decode.field("task_template", task_template_decoder(), decode.success)
  core.request("POST", "/api/v1/task-templates", Some(body), decoder, to_msg)
}

/// Create project-scoped task template.
pub fn create_project_template(
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  to_msg: fn(ApiResult(TaskTemplate)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("type_id", json.int(type_id)),
      #("priority", json.int(priority)),
    ])
  let decoder =
    decode.field("task_template", task_template_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
    Some(body),
    decoder,
    to_msg,
  )
}

/// Update task template.
pub fn update_template(
  template_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  to_msg: fn(ApiResult(TaskTemplate)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("type_id", json.int(type_id)),
      #("priority", json.int(priority)),
    ])
  let decoder =
    decode.field("task_template", task_template_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/task-templates/" <> int.to_string(template_id),
    Some(body),
    decoder,
    to_msg,
  )
}

/// Delete task template.
pub fn delete_template(
  template_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/task-templates/" <> int.to_string(template_id),
    None,
    to_msg,
  )
}
