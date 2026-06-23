//// Database operations for workflow rules and their selected task template.
////
//// ## Mission
////
//// Provide repository and mapping for workflow rules and their selected template.
////
//// ## Responsibilities
////
//// - Query and mutate rule records
//// - Map SQL rows into domain types
//// - Select the single template used by a rule
////
//// ## Non-responsibilities
////
//// - Rule evaluation (see `use_case/rules_engine.gleam`)
//// - HTTP request handling (see `http/rules.gleam`)
////
//// ## Relationships
////
//// - Uses `domain/workflow.gleam` for typed rule targets
//// - Executes queries from `sql.gleam`

import domain/automation
import domain/workflow
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/service_error.{
  type ServiceError, DbError, InvalidReference, NotFound, Unexpected,
}

/// Persisted rule record with a typed target and without loaded templates.
pub type RuleRecord {
  RuleRecord(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: Option(String),
    trigger: automation.AutomationTrigger,
    target: workflow.RuleTarget,
    active: Bool,
    created_at: String,
  )
}

// =============================================================================
// Helpers
// =============================================================================

fn rule_from_list_row(
  row: sql.RulesListForWorkflowRow,
) -> Result(RuleRecord, ServiceError) {
  rule_from_fields(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    trigger_kind: row.trigger_kind,
    resource_type: row.resource_type,
    task_type_id: row.task_type_id,
    to_state: row.to_state,
    active: row.active,
    created_at: row.created_at,
  )
}

fn rule_from_get_row(row: sql.RulesGetRow) -> Result(RuleRecord, ServiceError) {
  rule_from_fields(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    trigger_kind: row.trigger_kind,
    resource_type: row.resource_type,
    task_type_id: row.task_type_id,
    to_state: row.to_state,
    active: row.active,
    created_at: row.created_at,
  )
}

fn rule_from_create_row(
  row: sql.RulesCreateRow,
) -> Result(RuleRecord, ServiceError) {
  rule_from_fields(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    trigger_kind: row.trigger_kind,
    resource_type: row.resource_type,
    task_type_id: row.task_type_id,
    to_state: row.to_state,
    active: row.active,
    created_at: row.created_at,
  )
}

fn rule_from_update_row(
  row: sql.RulesUpdateRow,
) -> Result(RuleRecord, ServiceError) {
  rule_from_fields(
    id: row.id,
    workflow_id: row.workflow_id,
    name: row.name,
    goal: option_helpers.string_to_option(row.goal),
    trigger_kind: row.trigger_kind,
    resource_type: row.resource_type,
    task_type_id: row.task_type_id,
    to_state: row.to_state,
    active: row.active,
    created_at: row.created_at,
  )
}

fn rule_from_fields(
  id id: Int,
  workflow_id workflow_id: Int,
  name name: String,
  goal goal: Option(String),
  trigger_kind trigger_kind: String,
  resource_type resource_type: String,
  task_type_id task_type_id: Int,
  to_state to_state: String,
  active active: Bool,
  created_at created_at: String,
) -> Result(RuleRecord, ServiceError) {
  use target <- result.try(parse_stored_target(
    resource_type,
    task_type_id,
    to_state,
  ))
  use trigger <- result.try(parse_stored_trigger(trigger_kind, task_type_id))

  Ok(RuleRecord(
    id: id,
    workflow_id: workflow_id,
    name: name,
    goal: goal,
    trigger: trigger,
    target: target,
    active: active,
    created_at: created_at,
  ))
}

fn template_from_row(
  row: sql.RuleTemplatesListForRuleRow,
) -> Result(workflow.RuleTemplate, ServiceError) {
  Ok(workflow.RuleTemplate(
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
  ))
}

fn target_error_to_stored_error(
  error: workflow.RuleTargetValidationError,
  resource_type: String,
  task_type_id: Int,
  to_state: String,
) -> ServiceError {
  Unexpected(
    "Invalid persisted rule target: "
    <> workflow.rule_target_validation_error_label(error)
    <> " (resource_type="
    <> resource_type
    <> ", task_type_id="
    <> int.to_string(task_type_id)
    <> ", to_state="
    <> to_state
    <> ")",
  )
}

fn trigger_error_to_stored_error(
  error: automation.TriggerKindParseError,
  trigger_kind: String,
) -> ServiceError {
  case error {
    automation.UnknownTriggerKind(_) ->
      Unexpected("Invalid persisted rule trigger_kind: " <> trigger_kind)
  }
}

fn db_task_type_id(value: Int) -> Option(Int) {
  case value {
    id if id > 0 -> Some(id)
    _ -> None
  }
}

fn parse_stored_trigger(
  trigger_kind: String,
  task_type_id: Int,
) -> Result(automation.AutomationTrigger, ServiceError) {
  automation.trigger_from_kind(trigger_kind, db_task_type_id(task_type_id))
  |> result.map_error(fn(error) {
    trigger_error_to_stored_error(error, trigger_kind)
  })
}

fn parse_stored_target(
  resource_type: String,
  task_type_id: Int,
  to_state: String,
) -> Result(workflow.RuleTarget, ServiceError) {
  workflow.parse_rule_target(
    resource_type,
    db_task_type_id(task_type_id),
    to_state,
  )
  |> result.map_error(fn(error) {
    target_error_to_stored_error(error, resource_type, task_type_id, to_state)
  })
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
) -> Result(List(RuleRecord), ServiceError) {
  use returned <- result.try(
    sql.rules_list_for_workflow(db, workflow_id)
    |> result.map_error(DbError),
  )

  list.try_map(returned.rows, rule_from_list_row)
}

/// Fetches a single rule by id.
///
/// Example:
///   get_rule(db, rule_id)
pub fn get_rule(
  db: pog.Connection,
  rule_id: Int,
) -> Result(RuleRecord, ServiceError) {
  case sql.rules_get(db, rule_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> rule_from_get_row(row)
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
  target: workflow.RuleTarget,
  active: Bool,
) -> Result(RuleRecord, ServiceError) {
  let #(resource_type_value, task_type_value, to_state_value) =
    workflow.rule_target_to_db_values(target)
  use trigger <- result.try(rule_target_to_trigger(target))
  let trigger_kind_value = automation.trigger_kind(trigger)

  create_rule_in_db(
    db,
    workflow_id,
    name,
    goal,
    resource_type_value,
    trigger_kind_value,
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
  trigger_kind_value: String,
  task_type_value: Int,
  to_state_value: String,
  active: Bool,
) -> Result(RuleRecord, ServiceError) {
  case
    sql.rules_create(
      db,
      workflow_id,
      name,
      goal,
      resource_type_value,
      trigger_kind_value,
      task_type_value,
      to_state_value,
      active,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> rule_from_create_row(row)
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
  target: Option(workflow.RuleTarget),
  active: Option(Bool),
) -> Result(RuleRecord, ServiceError) {
  case sql.rules_get(db, rule_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      update_rule_with_row(db, rule_id, row, name, goal, target, active)
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
  target: Option(workflow.RuleTarget),
  active: Option(Bool),
) -> Result(RuleRecord, ServiceError) {
  let name_value = option_helpers.option_to_value(name, row.name)
  let goal_value = option_helpers.option_to_value(goal, row.goal)
  let active_value = option_helpers.option_to_value(active, row.active)

  use stored_target <- result.try(parse_stored_target(
    row.resource_type,
    row.task_type_id,
    row.to_state,
  ))
  let target_value = option_helpers.option_to_value(target, stored_target)
  use trigger <- result.try(rule_target_to_trigger(target_value))
  let #(resource_type_param, task_type_param, to_state_param) =
    workflow.rule_target_to_db_values(target_value)
  let trigger_kind_param = automation.trigger_kind(trigger)
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
    trigger_kind_param,
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
  trigger_kind_param: String,
  task_type_param: Int,
  to_state_param: String,
  active_flag: Int,
) -> Result(RuleRecord, ServiceError) {
  case
    sql.rules_update(
      db,
      rule_id,
      name_value,
      goal_value,
      resource_type_param,
      trigger_kind_param,
      task_type_param,
      to_state_param,
      active_flag,
    )
  {
    Ok(pog.Returned(rows: [updated_row, ..], ..)) ->
      rule_from_update_row(updated_row)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(error) -> Error(map_update_rule_error(error))
  }
}

fn rule_target_to_trigger(
  target: workflow.RuleTarget,
) -> Result(automation.AutomationTrigger, ServiceError) {
  workflow.rule_target_to_automation_trigger(target)
  |> result.map_error(fn(error) {
    Unexpected(rule_target_trigger_error_label(error))
  })
}

fn rule_target_trigger_error_label(
  error: workflow.RuleTargetTriggerError,
) -> String {
  case error {
    workflow.AmbiguousTaskAvailableTrigger ->
      "Task available target must be represented as TaskCreated or TaskReleased"
    workflow.UnsupportedCardDraftTrigger ->
      "Draft cards are not automation triggers"
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

/// Lists templates selected for a rule.
///
/// Example:
///   list_rule_templates(db, rule_id)
pub fn list_rule_templates(
  db: pog.Connection,
  rule_id: Int,
) -> Result(List(workflow.RuleTemplate), ServiceError) {
  use returned <- result.try(
    sql.rule_templates_list_for_rule(db, rule_id)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.try_map(template_from_row)
}

/// Selects the single template used by a rule.
///
/// Example:
///   select_template(db, rule_id, template_id, 1)
pub fn select_template(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
) -> Result(Nil, ServiceError) {
  case sql.rule_templates_select(db, rule_id, template_id, execution_order) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(Nil)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}
