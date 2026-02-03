//// Database operations for workflow rules and template attachments.
////
//// ## Mission
////
//// Provide persistence and mapping for workflow rules and their template links.
////
//// ## Responsibilities
////
//// - Query and mutate rule records
//// - Map SQL rows into domain types
//// - Attach and detach rule templates
////
//// ## Non-responsibilities
////
//// - Rule evaluation (see `services/rules_engine.gleam`)
//// - HTTP request handling (see `http/rules.gleam`)
////
//// ## Relationships
////
//// - Uses `services/rules_target.gleam` for typed rule targets
//// - Executes queries from `sql.gleam`

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/services/rules_target
import scrumbringer_server/services/service_error.{
  type ServiceError, DbError, InvalidReference, NotFound,
}
import scrumbringer_server/sql

/// Rule record with a typed target.
pub type Rule {
  Rule(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: Option(String),
    target: rules_target.RuleTarget,
    active: Bool,
    created_at: String,
  )
}

/// Template associated with a rule, including execution order.
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

// =============================================================================
// Helpers
// =============================================================================

fn rule_from_list_row(row: sql.RulesListForWorkflowRow) -> Rule {
  let assert Ok(target) =
    rules_target.from_strings(row.resource_type, row.task_type_id, row.to_state)
  Rule(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    target: target,
    active: row.active,
    created_at: row.created_at,
  )
}

fn rule_from_get_row(row: sql.RulesGetRow) -> Rule {
  let assert Ok(target) =
    rules_target.from_strings(row.resource_type, row.task_type_id, row.to_state)
  Rule(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    target: target,
    active: row.active,
    created_at: row.created_at,
  )
}

fn rule_from_create_row(row: sql.RulesCreateRow) -> Rule {
  let assert Ok(target) =
    rules_target.from_strings(row.resource_type, row.task_type_id, row.to_state)
  Rule(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    target: target,
    active: row.active,
    created_at: row.created_at,
  )
}

fn rule_from_update_row(row: sql.RulesUpdateRow) -> Rule {
  let assert Ok(target) =
    rules_target.from_strings(row.resource_type, row.task_type_id, row.to_state)
  Rule(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    target: target,
    active: row.active,
    created_at: row.created_at,
  )
}

fn template_from_row(row: sql.RuleTemplatesListForRuleRow) -> RuleTemplate {
  RuleTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: option_helpers.int_to_option(row.project_id),
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    type_id: row.type_id,
    type_name: row.type_name,
    priority: row.priority,
    created_by: row.created_by,
    created_at: row.created_at,
    execution_order: row.execution_order,
  )
}

fn target_error_to_create_error(
  error: rules_target.RuleTargetError,
) -> ServiceError {
  case error {
    rules_target.InvalidResourceType -> InvalidReference("resource_type")
    rules_target.TaskTypeNotAllowedForCard -> InvalidReference("task_type_id")
  }
}

fn target_error_to_update_error(
  error: rules_target.RuleTargetError,
) -> ServiceError {
  case error {
    rules_target.InvalidResourceType -> InvalidReference("resource_type")
    rules_target.TaskTypeNotAllowedForCard -> InvalidReference("task_type_id")
  }
}

// =============================================================================
// Public API
// =============================================================================

/// Lists rules for a workflow.
///
/// Example:
///   list_rules_for_workflow(db, workflow_id)
pub fn list_rules_for_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(List(Rule), pog.QueryError) {
  use returned <- result.try(sql.rules_list_for_workflow(db, workflow_id))

  returned.rows
  |> list.map(rule_from_list_row)
  |> Ok
}

/// Fetches a single rule by id.
///
/// Example:
///   get_rule(db, rule_id)
pub fn get_rule(db: pog.Connection, rule_id: Int) -> Result(Rule, ServiceError) {
  case sql.rules_get(db, rule_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(rule_from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Creates a new rule for a workflow.
///
/// Example:
///   create_rule(db, workflow_id, name, goal, target)
pub fn create_rule(
  db: pog.Connection,
  workflow_id: Int,
  name: String,
  goal: String,
  resource_type: String,
  task_type_id: Int,
  to_state: String,
  active: Bool,
) -> Result(Rule, ServiceError) {
  use target <- result.try(
    rules_target.from_strings(resource_type, task_type_id, to_state)
    |> result.map_error(target_error_to_create_error),
  )
  let #(resource_type_value, task_type_value, to_state_value) =
    rules_target.to_db_values(target)

  create_rule_in_db(
    db,
    workflow_id,
    name,
    goal,
    resource_type_value,
    task_type_value,
    to_state_value,
    active,
  )
}

fn create_rule_in_db(
  db: pog.Connection,
  workflow_id: Int,
  name: String,
  goal: String,
  resource_type_value: String,
  task_type_value: Int,
  to_state_value: String,
  active: Bool,
) -> Result(Rule, ServiceError) {
  case
    sql.rules_create(
      db,
      workflow_id,
      name,
      goal,
      resource_type_value,
      task_type_value,
      to_state_value,
      active,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(rule_from_create_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(InvalidReference("workflow_id"))
    Error(error) -> Error(map_create_rule_error(error))
  }
}

fn map_create_rule_error(error: pog.QueryError) -> ServiceError {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      map_create_rule_constraint(error, constraint)
    _ -> DbError(error)
  }
}

fn map_create_rule_constraint(
  error: pog.QueryError,
  constraint: String,
) -> ServiceError {
  case string.contains(constraint, "task_types") {
    True -> InvalidReference("task_type_id")
    False -> DbError(error)
  }
}

/// Updates an existing rule.
///
/// Example:
///   update_rule(db, rule_id, name, goal, target)
pub fn update_rule(
  db: pog.Connection,
  rule_id: Int,
  name: Option(String),
  goal: Option(String),
  resource_type: Option(String),
  task_type_id: Option(Int),
  to_state: Option(String),
  active: Option(Bool),
) -> Result(Rule, ServiceError) {
  case sql.rules_get(db, rule_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      update_rule_with_row(
        db,
        rule_id,
        row,
        name,
        goal,
        resource_type,
        task_type_id,
        to_state,
        active,
      )
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(error) -> Error(DbError(error))
  }
}

fn update_rule_with_row(
  db: pog.Connection,
  rule_id: Int,
  row: sql.RulesGetRow,
  name: Option(String),
  goal: Option(String),
  resource_type: Option(String),
  task_type_id: Option(Int),
  to_state: Option(String),
  active: Option(Bool),
) -> Result(Rule, ServiceError) {
  let name_value = case name {
    Some(value) -> value
    None -> row.name
  }
  let goal_value = case goal {
    Some(value) -> value
    None -> row.goal
  }
  let resource_type_value = case resource_type {
    Some(value) -> value
    None -> row.resource_type
  }
  let task_type_value = case task_type_id {
    Some(value) -> value
    None -> row.task_type_id
  }
  let to_state_value = case to_state {
    Some(value) -> value
    None -> row.to_state
  }
  let active_value = case active {
    Some(value) -> value
    None -> row.active
  }

  use target <- result.try(
    rules_target.from_strings(
      resource_type_value,
      task_type_value,
      to_state_value,
    )
    |> result.map_error(target_error_to_update_error),
  )
  let #(resource_type_param, task_type_param, to_state_param) =
    rules_target.to_db_values(target)
  let active_flag = case active_value {
    True -> 1
    False -> 0
  }

  update_rule_in_db(
    db,
    rule_id,
    name_value,
    goal_value,
    resource_type_param,
    task_type_param,
    to_state_param,
    active_flag,
  )
}

fn update_rule_in_db(
  db: pog.Connection,
  rule_id: Int,
  name_value: String,
  goal_value: String,
  resource_type_param: String,
  task_type_param: Int,
  to_state_param: String,
  active_flag: Int,
) -> Result(Rule, ServiceError) {
  case
    sql.rules_update(
      db,
      rule_id,
      name_value,
      goal_value,
      resource_type_param,
      task_type_param,
      to_state_param,
      active_flag,
    )
  {
    Ok(pog.Returned(rows: [updated_row, ..], ..)) ->
      Ok(rule_from_update_row(updated_row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(error) -> Error(map_update_rule_error(error))
  }
}

fn map_update_rule_error(error: pog.QueryError) -> ServiceError {
  case error {
    pog.ConstraintViolated(constraint: constraint, ..) ->
      map_update_rule_constraint(error, constraint)
    _ -> DbError(error)
  }
}

fn map_update_rule_constraint(
  error: pog.QueryError,
  constraint: String,
) -> ServiceError {
  case string.contains(constraint, "task_types") {
    True -> InvalidReference("task_type_id")
    False -> DbError(error)
  }
}

/// Deletes a rule by id.
///
/// Example:
///   delete_rule(db, rule_id)
pub fn delete_rule(
  db: pog.Connection,
  rule_id: Int,
) -> Result(Nil, ServiceError) {
  case sql.rules_delete(db, rule_id) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Lists templates attached to a rule.
///
/// Example:
///   list_rule_templates(db, rule_id)
pub fn list_rule_templates(
  db: pog.Connection,
  rule_id: Int,
) -> Result(List(RuleTemplate), pog.QueryError) {
  use returned <- result.try(sql.rule_templates_list_for_rule(db, rule_id))

  returned.rows
  |> list.map(template_from_row)
  |> Ok
}

/// Attaches a template to a rule with an execution order.
///
/// Example:
///   attach_template(db, rule_id, template_id, 1)
pub fn attach_template(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
) -> Result(Nil, ServiceError) {
  case sql.rule_templates_attach(db, rule_id, template_id, execution_order) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

/// Detaches a template from a rule.
///
/// Example:
///   detach_template(db, rule_id, template_id)
pub fn detach_template(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
) -> Result(Nil, ServiceError) {
  case sql.rule_templates_detach(db, rule_id, template_id) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}
