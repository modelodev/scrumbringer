//// Domain types for workflows, rules, and task templates.

import domain/card
import domain/task_status
import gleam/option.{type Option, None, Some}
import gleam/result

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
    target: RuleTarget,
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

/// Rule target validation errors for values crossing JSON/DB boundaries.
pub type RuleTargetValidationError {
  UnknownRuleResourceType(String)
  InvalidTaskRuleState(String)
  InvalidCardRuleState(String)
  CardRuleCannotHaveTaskType
}

/// Typed target for a workflow rule.
///
/// Rule payloads and DB rows cross boundaries as strings, but application code
/// should use this type once those values have been validated.
pub type RuleTarget {
  TaskRule(to_state: task_status.TaskPhase, task_type_id: Option(Int))
  CardRule(to_state: card.CardPhase)
}

/// Parse a string-backed rule target into its typed domain representation.
pub fn parse_rule_target(
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
) -> Result(RuleTarget, RuleTargetValidationError) {
  case resource_type {
    "task" -> {
      use parsed_state <- result.try(parse_task_rule_state(to_state))
      Ok(TaskRule(parsed_state, task_type_id))
    }

    "card" ->
      case task_type_id {
        Some(_) -> Error(CardRuleCannotHaveTaskType)
        None -> {
          use parsed_state <- result.try(parse_card_rule_state(to_state))
          Ok(CardRule(parsed_state))
        }
      }

    other -> Error(UnknownRuleResourceType(other))
  }
}

/// Validate string-backed rule target fields at a JSON or DB boundary.
pub fn validate_rule_target(
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
) -> Result(Nil, RuleTargetValidationError) {
  case parse_rule_target(resource_type, task_type_id, to_state) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

pub fn rule_target_resource_type(target: RuleTarget) -> String {
  case target {
    TaskRule(_, _) -> "task"
    CardRule(_) -> "card"
  }
}

pub fn rule_target_task_type_id(target: RuleTarget) -> Option(Int) {
  case target {
    TaskRule(_, task_type_id) -> task_type_id
    CardRule(_) -> None
  }
}

pub fn rule_target_to_state_string(target: RuleTarget) -> String {
  case target {
    TaskRule(to_state, _) -> task_status.task_status_to_string(to_state)
    CardRule(to_state) -> card.state_to_string(to_state)
  }
}

pub fn rule_target_to_db_values(target: RuleTarget) -> #(String, Int, String) {
  let resource_type = rule_target_resource_type(target)
  let to_state = rule_target_to_state_string(target)
  let task_type_id = case rule_target_task_type_id(target) {
    Some(id) -> id
    None -> 0
  }

  #(resource_type, task_type_id, to_state)
}

pub fn rule_resource_type(rule: Rule) -> String {
  rule_target_resource_type(rule.target)
}

pub fn rule_task_type_id(rule: Rule) -> Option(Int) {
  rule_target_task_type_id(rule.target)
}

pub fn rule_to_state_string(rule: Rule) -> String {
  rule_target_to_state_string(rule.target)
}

pub fn rule_target_validation_error_label(
  error: RuleTargetValidationError,
) -> String {
  case error {
    UnknownRuleResourceType(_) -> "Unknown rule resource_type"
    InvalidTaskRuleState(_) -> "Invalid task rule to_state"
    InvalidCardRuleState(_) -> "Invalid card rule to_state"
    CardRuleCannotHaveTaskType -> "Card rule cannot have task_type_id"
  }
}

fn parse_task_rule_state(
  value: String,
) -> Result(task_status.TaskPhase, RuleTargetValidationError) {
  case task_status.parse_task_status(value) {
    Ok(state) -> Ok(state)
    Error(_) -> Error(InvalidTaskRuleState(value))
  }
}

fn parse_card_rule_state(
  value: String,
) -> Result(card.CardPhase, RuleTargetValidationError) {
  case card.parse_state(value) {
    Ok(state) -> Ok(state)
    Error(_) -> Error(InvalidCardRuleState(value))
  }
}
