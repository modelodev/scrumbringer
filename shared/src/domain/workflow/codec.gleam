//// Workflow JSON decoders.

import gleam/dynamic/decode

import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow, Rule,
  RuleTemplate, TaskTemplate, Workflow,
}

// =============================================================================
// Decoders
// =============================================================================

/// Decoder for Workflow.
pub fn workflow_decoder() -> decode.Decoder(Workflow) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
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

/// Decoder for Rule.
/// Story 4.10: Added templates field decoding.
pub fn rule_decoder() -> decode.Decoder(Rule) {
  use id <- decode.field("id", decode.int)
  use workflow_id <- decode.field("workflow_id", decode.int)
  use name <- decode.field("name", decode.string)
  use goal <- decode.field("goal", decode.optional(decode.string))
  use resource_type <- decode.field("resource_type", decode.string)
  use task_type_id <- decode.field("task_type_id", decode.optional(decode.int))
  use to_state <- decode.field("to_state", decode.string)
  use active <- decode.field("active", decode.bool)
  use created_at <- decode.field("created_at", decode.string)
  use templates <- decode.optional_field(
    "templates",
    [],
    decode.list(rule_template_decoder()),
  )
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
    templates: templates,
  ))
}

/// Decoder for TaskTemplate.
/// Story 4.9 AC20: Added rules_count field.
pub fn task_template_decoder() -> decode.Decoder(TaskTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use rules_count <- decode.optional_field("rules_count", 0, decode.int)
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
    rules_count: rules_count,
  ))
}

/// Decoder for RuleTemplate.
pub fn rule_template_decoder() -> decode.Decoder(RuleTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
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
