////
//// Rules Engine for workflow automation.
////
//// Evaluates rules against state change events and creates tasks from templates.
//// Implements idempotency via rule_executions tracking.
////
//// ## Logging
////
//// Set SB_RULES_ENGINE_LOG=true to enable debug logging for rule evaluation.
//// This helps diagnose why rules might not be firing or creating tasks.

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql

// =============================================================================
// Logging
// =============================================================================

fn is_logging_enabled() -> Bool {
  case envoy.get("SB_RULES_ENGINE_LOG") {
    Ok("true") | Ok("1") -> True
    _ -> False
  }
}

fn log(message: String) -> Nil {
  case is_logging_enabled() {
    True -> io.println("[RulesEngine] " <> message)
    False -> Nil
  }
}

fn log_event(event: StateChangeEvent) -> Nil {
  log(
    "Event: "
    <> resource_type_to_string(event.resource_type)
    <> " #"
    <> int.to_string(event.resource_id)
    <> " -> "
    <> event.to_state
    <> " (project="
    <> int.to_string(event.project_id)
    <> ", org="
    <> int.to_string(event.org_id)
    <> ", task_type="
    <> option.map(event.task_type_id, int.to_string)
    |> option.unwrap("none")
    <> ", user_triggered="
    <> case event.user_triggered {
      True -> "true"
      False -> "false"
    }
    <> ")",
  )
}

// =============================================================================
// Types
// =============================================================================

/// Resource types that can trigger rules.
pub type ResourceType {
  Task
  Card
}

/// Context for a task that triggers rules.
/// Groups related task data to reduce parameter count.
pub type TaskContext {
  TaskContext(
    task_id: Int,
    project_id: Int,
    org_id: Int,
    type_id: Int,
    card_id: Option(Int),
  )
}

/// State change event that may trigger rules.
///
/// ## Fields
/// - `card_id`: For task events, the parent card (if any).
///   Tasks created by rules inherit this value.
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
    card_id: Option(Int),
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
// Event Builders
// =============================================================================

/// Build a state change event for a task transition.
pub fn task_event(
  ctx: TaskContext,
  user_id: Int,
  from_state: Option(String),
  to_state: String,
) -> StateChangeEvent {
  StateChangeEvent(
    resource_type: Task,
    resource_id: ctx.task_id,
    from_state: from_state,
    to_state: to_state,
    project_id: ctx.project_id,
    org_id: ctx.org_id,
    user_id: user_id,
    user_triggered: True,
    task_type_id: option.Some(ctx.type_id),
    card_id: ctx.card_id,
  )
}

/// Build a state change event for a card state change.
/// Cards don't inherit card_id (they are the parent).
pub fn card_event(
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  to_state: String,
) -> StateChangeEvent {
  StateChangeEvent(
    resource_type: Card,
    resource_id: card_id,
    from_state: option.None,
    to_state: to_state,
    project_id: project_id,
    org_id: org_id,
    user_id: user_id,
    user_triggered: True,
    task_type_id: option.None,
    card_id: option.None,
  )
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
  log_event(event)

  // Skip if not user-triggered
  case event.user_triggered {
    False -> {
      log("Skipped: event not user-triggered")
      Ok([])
    }
    True -> {
      // Find matching active rules
      use rules <- result.try(find_matching_rules(db, event))

      log("Found " <> int.to_string(list.length(rules)) <> " matching rule(s)")

      // Evaluate each rule
      let results =
        rules
        |> list.map(fn(rule) {
          log("Evaluating rule: " <> rule.name <> " (id=" <> int.to_string(rule.id) <> ")")
          evaluate_single_rule(db, rule, event)
        })
        |> result.all

      case results {
        Ok(r) -> {
          let applied = list.filter(r, fn(rr) {
            case rr.outcome {
              Applied(_) -> True
              Suppressed(_) -> False
            }
          })
          log("Completed: " <> int.to_string(list.length(applied)) <> " rule(s) applied")
        }
        Error(e) -> {
          log("Error during rule evaluation: " <> debug_error(e))
        }
      }

      results
    }
  }
}

fn debug_error(e: RuleEngineError) -> String {
  case e {
    DbError(pog.ConstraintViolated(_, constraint, _)) -> "constraint: " <> constraint
    DbError(pog.UnexpectedArgumentCount(expected, got)) ->
      "unexpected args: expected " <> int.to_string(expected) <> ", got " <> int.to_string(got)
    DbError(_) -> "database error"
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
          goal: option_helpers.string_to_option(row.goal),
          resource_type: row.resource_type,
          task_type_id: option_helpers.int_to_option(row.task_type_id),
          to_state: row.to_state,
          active: row.active,
          created_at: row.created_at,
          workflow_org_id: row.workflow_org_id,
          workflow_project_id: option_helpers.int_to_option(row.workflow_project_id),
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
    Error(e) -> {
      log("  Error checking idempotency: " <> debug_error(e))
      Error(e)
    }
    Ok(True) -> {
      log("  Suppressed: already executed for this resource")
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

      log("  Found " <> int.to_string(list.length(templates)) <> " template(s)")

      case templates {
        [] -> {
          log("  Applied: no templates to execute")
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

          log("  Applied: created " <> int.to_string(tasks_created) <> " task(s)")

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
          project_id: option_helpers.int_to_option(row.project_id),
          name: row.name,
          description: option_helpers.string_to_option(row.description),
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

  // Inherit card_id from triggering task (0 means no card)
  let card_id_param = option.unwrap(event.card_id, 0)

  log(
    "    Creating task: \""
    <> title
    <> "\" (type="
    <> int.to_string(template.type_id)
    <> ", card="
    <> int.to_string(card_id_param)
    <> ")",
  )

  // Create task via SQL
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
      card_id_param,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      log("    Created task #" <> int.to_string(row.id))
      Ok(row.id)
    }
    Ok(pog.Returned(rows: [], ..)) -> {
      log("    Error: task creation returned no rows")
      // This shouldn't happen but treat as no-op
      Error(DbError(pog.UnexpectedArgumentCount(7, 0)))
    }
    Error(e) -> {
      log("    Error creating task: " <> debug_error(DbError(e)))
      Error(DbError(e))
    }
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
