//// Domain types for workflows, rules, and task templates.

import gleam/option.{type Option}

/// Workflow container for automation rules.
pub type Workflow {
  Workflow(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: Option(String),
    active: Bool,
    rule_count: Int,
    created_by: Int,
    created_at: String,
  )
}

/// Rule trigger definition within a workflow.
/// Story 4.10: Added templates field for attached task templates.
pub type Rule {
  Rule(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: Option(String),
    resource_type: String,
    task_type_id: Option(Int),
    to_state: String,
    active: Bool,
    created_at: String,
    templates: List(RuleTemplate),
  )
}

/// Task template blueprint for automation.
/// Story 4.9 AC20: Added rules_count field.
pub type TaskTemplate {
  TaskTemplate(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: Option(String),
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
    rules_count: Int,
  )
}

/// Rule template association with execution order.
pub type RuleTemplate {
  RuleTemplate(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: Option(String),
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
    execution_order: Int,
  )
}
