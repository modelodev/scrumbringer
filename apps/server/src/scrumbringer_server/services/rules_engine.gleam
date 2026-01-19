////
//// Rules Engine for workflow automation.
////
//// Evaluates rules against state change events and creates tasks from templates.
//// Implements idempotency via rule_executions tracking.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/sql

// =============================================================================
// Types
// =============================================================================

/// Resource types that can trigger rules.
pub type ResourceType {
  Task
  Card
}

/// State change event that may trigger rules.
pub type StateChangeEvent {
  StateChangeEvent(
    resource_type: ResourceType,
    resource_id: Int,
    from_state: Option(String),
    to_state: String,
    project_id: Int,
    org_id: Int,
    user_id: Int,
    user_triggered: Bool,
    task_type_id: Option(Int),
  )
}

/// Result of evaluating a single rule.
pub type RuleResult {
  RuleResult(rule_id: Int, outcome: RuleOutcome)
}

/// Outcome of a rule evaluation.
pub type RuleOutcome {
  Applied(tasks_created: Int)
  Suppressed(reason: String)
}

/// Error during rule evaluation.
pub type RuleEngineError {
  DbError(pog.QueryError)
}

// =============================================================================
// Public API
// =============================================================================

/// Evaluate all matching rules for a state change event.
/// Returns list of rule results with outcomes.
pub fn evaluate_rules(
  db: pog.Connection,
  event: StateChangeEvent,
) -> Result(List(RuleResult), RuleEngineError) {
  // Skip if not user-triggered
  case event.user_triggered {
    False -> Ok([])
    True -> {
      // Find matching active rules
      use rules <- result.try(find_matching_rules(db, event))

      // Evaluate each rule
      rules
      |> list.map(fn(rule) { evaluate_single_rule(db, rule, event) })
      |> result.all
    }
  }
}

// =============================================================================
// Internal types for SQL mapping
// =============================================================================

type MatchingRule {
  MatchingRule(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: Option(String),
    resource_type: String,
    task_type_id: Option(Int),
    to_state: String,
    active: Bool,
    created_at: String,
    workflow_org_id: Int,
    workflow_project_id: Option(Int),
  )
}

type ExecutionTemplate {
  ExecutionTemplate(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: Option(String),
    type_id: Int,
    priority: Int,
    created_by: Int,
    created_at: String,
    execution_order: Int,
  )
}

// =============================================================================
// Internal Functions
// =============================================================================

fn find_matching_rules(
  db: pog.Connection,
  event: StateChangeEvent,
) -> Result(List(MatchingRule), RuleEngineError) {
  let resource_type_str = resource_type_to_string(event.resource_type)
  let task_type_param = option.unwrap(event.task_type_id, -1)

  case
    sql.rules_find_matching(
      db,
      resource_type_str,
      event.to_state,
      event.project_id,
      event.org_id,
      task_type_param,
    )
  {
    Ok(returned) ->
      returned.rows
      |> list.map(fn(row) {
        MatchingRule(
          id: row.id,
          workflow_id: row.workflow_id,
          name: row.name,
          goal: string_to_option(row.goal),
          resource_type: row.resource_type,
          task_type_id: int_to_option(row.task_type_id),
          to_state: row.to_state,
          active: row.active,
          created_at: row.created_at,
          workflow_org_id: row.workflow_org_id,
          workflow_project_id: int_to_option(row.workflow_project_id),
        )
      })
      |> Ok

    Error(e) -> Error(DbError(e))
  }
}

fn evaluate_single_rule(
  db: pog.Connection,
  rule: MatchingRule,
  event: StateChangeEvent,
) -> Result(RuleResult, RuleEngineError) {
  let origin_type = resource_type_to_string(event.resource_type)

  // Check idempotency
  case check_already_executed(db, rule.id, origin_type, event.resource_id) {
    Error(e) -> Error(e)
    Ok(True) -> {
      // Already executed, log suppression
      let _ =
        log_execution(
          db,
          rule.id,
          origin_type,
          event.resource_id,
          "suppressed",
          "idempotent",
          event.user_id,
        )
      Ok(RuleResult(rule.id, Suppressed("idempotent")))
    }
    Ok(False) -> {
      // Execute: get templates and create tasks
      use templates <- result.try(get_rule_templates(db, rule.id))

      case templates {
        [] -> {
          // No templates, but rule fired
          let _ =
            log_execution(
              db,
              rule.id,
              origin_type,
              event.resource_id,
              "applied",
              "",
              event.user_id,
            )
          Ok(RuleResult(rule.id, Applied(0)))
        }

        _ -> {
          // Create tasks from templates
          use tasks_created <- result.try(
            create_tasks_from_templates(db, templates, event),
          )

          // Log execution
          let _ =
            log_execution(
              db,
              rule.id,
              origin_type,
              event.resource_id,
              "applied",
              "",
              event.user_id,
            )

          Ok(RuleResult(rule.id, Applied(tasks_created)))
        }
      }
    }
  }
}

fn check_already_executed(
  db: pog.Connection,
  rule_id: Int,
  origin_type: String,
  origin_id: Int,
) -> Result(Bool, RuleEngineError) {
  case sql.rule_executions_check(db, rule_id, origin_type, origin_id) {
    Ok(pog.Returned(rows: [_, ..], ..)) -> Ok(True)
    Ok(pog.Returned(rows: [], ..)) -> Ok(False)
    Error(e) -> Error(DbError(e))
  }
}

fn get_rule_templates(
  db: pog.Connection,
  rule_id: Int,
) -> Result(List(ExecutionTemplate), RuleEngineError) {
  case sql.rules_get_templates_for_execution(db, rule_id) {
    Ok(returned) ->
      returned.rows
      |> list.map(fn(row) {
        ExecutionTemplate(
          id: row.id,
          org_id: row.org_id,
          project_id: int_to_option(row.project_id),
          name: row.name,
          description: string_to_option(row.description),
          type_id: row.type_id,
          priority: row.priority,
          created_by: row.created_by,
          created_at: row.created_at,
          execution_order: row.execution_order,
        )
      })
      |> Ok

    Error(e) -> Error(DbError(e))
  }
}

fn create_tasks_from_templates(
  db: pog.Connection,
  templates: List(ExecutionTemplate),
  event: StateChangeEvent,
) -> Result(Int, RuleEngineError) {
  // Get variable values for substitution
  let project_name = get_project_name(db, event.project_id)
  let user_name = get_user_name(db, event.user_id)

  // Create a task for each template
  let results =
    templates
    |> list.map(fn(template) {
      create_task_from_template(db, template, event, project_name, user_name)
    })

  // Count successes
  let created =
    results
    |> list.filter(fn(r) {
      case r {
        Ok(_) -> True
        Error(_) -> False
      }
    })
    |> list.length

  Ok(created)
}

fn create_task_from_template(
  db: pog.Connection,
  template: ExecutionTemplate,
  event: StateChangeEvent,
  project_name: String,
  user_name: String,
) -> Result(Int, RuleEngineError) {
  let title = substitute_variables(template.name, event, project_name, user_name)
  let description =
    substitute_variables(
      option.unwrap(template.description, ""),
      event,
      project_name,
      user_name,
    )

  // Create task via SQL
  // Using existing tasks_create query params:
  // $1=type_id, $2=project_id, $3=title, $4=description, $5=priority, $6=created_by, $7=card_id
  case
    sql.tasks_create(
      db,
      template.type_id,
      event.project_id,
      title,
      description,
      template.priority,
      event.user_id,
      0,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row.id)
    Ok(pog.Returned(rows: [], ..)) ->
      // This shouldn't happen but treat as no-op
      Error(DbError(pog.UnexpectedArgumentCount(7, 0)))
    Error(e) -> Error(DbError(e))
  }
}

fn substitute_variables(
  text: String,
  event: StateChangeEvent,
  project_name: String,
  user_name: String,
) -> String {
  let father = format_father_link(event)
  let from_state = option.unwrap(event.from_state, "(created)")

  text
  |> string.replace("{{father}}", father)
  |> string.replace("{{from_state}}", from_state)
  |> string.replace("{{to_state}}", event.to_state)
  |> string.replace("{{project}}", project_name)
  |> string.replace("{{user}}", user_name)
}

fn format_father_link(event: StateChangeEvent) -> String {
  case event.resource_type {
    Task ->
      "[Task #"
      <> int.to_string(event.resource_id)
      <> "](/tasks/"
      <> int.to_string(event.resource_id)
      <> ")"
    Card ->
      "[Card #"
      <> int.to_string(event.resource_id)
      <> "](/cards/"
      <> int.to_string(event.resource_id)
      <> ")"
  }
}

fn get_project_name(db: pog.Connection, project_id: Int) -> String {
  case sql.engine_get_project_name(db, project_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> row.name
    _ -> "Unknown Project"
  }
}

fn get_user_name(db: pog.Connection, user_id: Int) -> String {
  case sql.engine_get_user_name(db, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> row.display_name
    _ -> "Unknown User"
  }
}

fn log_execution(
  db: pog.Connection,
  rule_id: Int,
  origin_type: String,
  origin_id: Int,
  outcome: String,
  suppression_reason: String,
  user_id: Int,
) -> Result(Nil, RuleEngineError) {
  case
    sql.rule_executions_log(
      db,
      rule_id,
      origin_type,
      origin_id,
      outcome,
      suppression_reason,
      user_id,
    )
  {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(DbError(e))
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn resource_type_to_string(rt: ResourceType) -> String {
  case rt {
    Task -> "task"
    Card -> "card"
  }
}

fn int_to_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    id -> Some(id)
  }
}

fn string_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    text -> Some(text)
  }
}
