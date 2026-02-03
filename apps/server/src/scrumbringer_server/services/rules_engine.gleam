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
import gleam/option
import gleam/result
import gleam/string
import helpers/option as option_helpers
import pog
import scrumbringer_server/services/rules_target
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

fn log_event(event: StateChange) -> Nil {
  log(
    "Event: "
    <> event_resource_type(event)
    <> " #"
    <> int.to_string(event_resource_id(event))
    <> " -> "
    <> event_to_state_string(event)
    <> " (project="
    <> int.to_string(event_project_id(event))
    <> ", org="
    <> int.to_string(event_org_id(event))
    <> ", task_type="
    <> option.map(event_task_type_id(event), int.to_string)
    |> option.unwrap("none")
    <> ", user_triggered="
    <> case event_user_triggered(event) {
      True -> "true"
      False -> "false"
    }
    <> ")",
  )
}

// =============================================================================
// Types
// =============================================================================

/// Context for a task that triggers rules.
/// Groups related task data to reduce parameter count.
pub type TaskContext {
  TaskContext(
    task_id: Int,
    project_id: Int,
    org_id: Int,
    type_id: Int,
    card_id: option.Option(Int),
  )
}

/// State change event that may trigger rules.
///
/// Task and card state values are string-backed but separated by type to
/// prevent cross-resource mixing.
pub type StateChange {
  TaskChange(
    ctx: TaskContext,
    from_state: option.Option(String),
    to_state: String,
    user_id: Int,
    user_triggered: Bool,
  )
  CardChange(
    card_id: Int,
    project_id: Int,
    org_id: Int,
    from_state: option.Option(String),
    to_state: String,
    user_id: Int,
    user_triggered: Bool,
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
  from_state: option.Option(String),
  to_state: String,
) -> StateChange {
  TaskChange(
    ctx: ctx,
    from_state: from_state,
    to_state: to_state,
    user_id: user_id,
    user_triggered: True,
  )
}

/// Build a state change event for a card state change.
/// Cards don't inherit card_id (they are the parent).
pub fn card_event(
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: option.Option(String),
  to_state: String,
) -> StateChange {
  CardChange(
    card_id: card_id,
    project_id: project_id,
    org_id: org_id,
    from_state: from_state,
    to_state: to_state,
    user_id: user_id,
    user_triggered: True,
  )
}

// =============================================================================
// Public API
// =============================================================================

/// Evaluate all matching rules for a state change event.
/// Returns list of rule results with outcomes.
pub fn evaluate_rules(
  db: pog.Connection,
  event: StateChange,
) -> Result(List(RuleResult), RuleEngineError) {
  log_event(event)

  // Skip if not user-triggered
  case event_user_triggered(event) {
    False -> {
      log("Skipped: event not user-triggered")
      Ok([])
    }
    True -> evaluate_user_triggered_rules(db, event)
  }
}

fn evaluate_user_triggered_rules(
  db: pog.Connection,
  event: StateChange,
) -> Result(List(RuleResult), RuleEngineError) {
  use rules <- result.try(find_matching_rules(db, event))

  log("Found " <> int.to_string(list.length(rules)) <> " matching rule(s)")

  let results =
    rules
    |> list.map(fn(rule) {
      log(
        "Evaluating rule: "
        <> rule.name
        <> " (id="
        <> int.to_string(rule.id)
        <> ")",
      )
      evaluate_single_rule(db, rule, event)
    })
    |> result.all

  log_results(results)

  results
}

fn log_results(results: Result(List(RuleResult), RuleEngineError)) -> Nil {
  case results {
    Ok(r) -> log_applied_results(r)
    Error(e) -> log("Error during rule evaluation: " <> debug_error(e))
  }
}

fn log_applied_results(results: List(RuleResult)) -> Nil {
  let applied = list.filter(results, is_rule_applied)
  log(
    "Completed: " <> int.to_string(list.length(applied)) <> " rule(s) applied",
  )
}

fn is_rule_applied(result: RuleResult) -> Bool {
  case result.outcome {
    Applied(_) -> True
    Suppressed(_) -> False
  }
}

fn debug_error(e: RuleEngineError) -> String {
  case e {
    DbError(pog.ConstraintViolated(_, constraint, _)) ->
      "constraint: " <> constraint
    DbError(pog.UnexpectedArgumentCount(expected, got)) ->
      "unexpected args: expected "
      <> int.to_string(expected)
      <> ", got "
      <> int.to_string(got)
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
    goal: option.Option(String),
    target: rules_target.RuleTarget,
    active: Bool,
    created_at: String,
    workflow_org_id: Int,
    workflow_project_id: option.Option(Int),
  )
}

type ExecutionTemplate {
  ExecutionTemplate(
    id: Int,
    org_id: Int,
    project_id: option.Option(Int),
    name: String,
    description: option.Option(String),
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
  event: StateChange,
) -> Result(List(MatchingRule), RuleEngineError) {
  let resource_type_str = event_resource_type(event)
  let task_type_param =
    option_helpers.option_to_value(event_task_type_id(event), 0)
  let to_state_value = event_to_state_string(event)

  case
    sql.rules_find_matching(
      db,
      resource_type_str,
      to_state_value,
      event_project_id(event),
      event_org_id(event),
      task_type_param,
    )
  {
    Ok(returned) ->
      returned.rows
      |> list.map(fn(row) {
        let assert Ok(target) =
          rules_target.from_strings(
            row.resource_type,
            row.task_type_id,
            row.to_state,
          )
        MatchingRule(
          id: row.id,
          workflow_id: row.workflow_id,
          name: row.name,
          goal: option_helpers.string_to_option(row.goal),
          target: target,
          active: row.active,
          created_at: row.created_at,
          workflow_org_id: row.workflow_org_id,
          workflow_project_id: option_helpers.int_to_option(
            row.workflow_project_id,
          ),
        )
      })
      |> Ok

    Error(e) -> Error(DbError(e))
  }
}

fn evaluate_single_rule(
  db: pog.Connection,
  rule: MatchingRule,
  event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  let origin_type = event_resource_type(event)
  let origin_id = event_resource_id(event)

  // Check idempotency
  case check_already_executed(db, rule.id, origin_type, origin_id) {
    Error(e) -> {
      log("  Error checking idempotency: " <> debug_error(e))
      Error(e)
    }
    Ok(True) ->
      suppress_idempotent_execution(db, rule, origin_type, origin_id, event)
    Ok(False) ->
      evaluate_rule_templates(db, rule, event, origin_type, origin_id)
  }
}

fn suppress_idempotent_execution(
  db: pog.Connection,
  rule: MatchingRule,
  origin_type: String,
  origin_id: Int,
  event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  log("  Suppressed: already executed for this resource")

  let _ =
    log_execution(
      db,
      rule.id,
      origin_type,
      origin_id,
      "suppressed",
      "idempotent",
      event_user_id(event),
    )

  Ok(RuleResult(rule.id, Suppressed("idempotent")))
}

fn evaluate_rule_templates(
  db: pog.Connection,
  rule: MatchingRule,
  event: StateChange,
  origin_type: String,
  origin_id: Int,
) -> Result(RuleResult, RuleEngineError) {
  use templates <- result.try(get_rule_templates(db, rule.id))

  log("  Found " <> int.to_string(list.length(templates)) <> " template(s)")

  case templates {
    [] -> apply_rule_without_templates(db, rule, origin_type, origin_id, event)
    _ ->
      apply_rule_with_templates(
        db,
        rule,
        templates,
        origin_type,
        origin_id,
        event,
      )
  }
}

fn apply_rule_without_templates(
  db: pog.Connection,
  rule: MatchingRule,
  origin_type: String,
  origin_id: Int,
  event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  log("  Applied: no templates to execute")

  let _ =
    log_execution(
      db,
      rule.id,
      origin_type,
      origin_id,
      "applied",
      "",
      event_user_id(event),
    )

  Ok(RuleResult(rule.id, Applied(0)))
}

fn apply_rule_with_templates(
  db: pog.Connection,
  rule: MatchingRule,
  templates: List(ExecutionTemplate),
  origin_type: String,
  origin_id: Int,
  event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  use tasks_created <- result.try(create_tasks_from_templates(
    db,
    templates,
    event,
  ))

  log("  Applied: created " <> int.to_string(tasks_created) <> " task(s)")

  let _ =
    log_execution(
      db,
      rule.id,
      origin_type,
      origin_id,
      "applied",
      "",
      event_user_id(event),
    )

  Ok(RuleResult(rule.id, Applied(tasks_created)))
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
  event: StateChange,
) -> Result(Int, RuleEngineError) {
  // Get variable values for substitution
  let project_name = get_project_name(db, event_project_id(event))
  let user_name = get_user_name(db, event_user_id(event))

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
  event: StateChange,
  project_name: String,
  user_name: String,
) -> Result(Int, RuleEngineError) {
  let title =
    substitute_variables(template.name, event, project_name, user_name)
  let description =
    substitute_variables(
      option.unwrap(template.description, ""),
      event,
      project_name,
      user_name,
    )

  // Inherit card_id from triggering task (None means no card)
  let card_id_param = event_card_id(event)
  let card_label = case card_id_param {
    option.None -> "none"
    option.Some(value) -> int.to_string(value)
  }

  log(
    "    Creating task: \""
    <> title
    <> "\" (type="
    <> int.to_string(template.type_id)
    <> ", card="
    <> card_label
    <> ")",
  )

  // Create task via SQL
  // $1=type_id, $2=project_id, $3=title, $4=description, $5=priority, $6=created_by, $7=card_id
  case
    sql.tasks_create(
      db,
      template.type_id,
      event_project_id(event),
      title,
      description,
      template.priority,
      event_user_id(event),
      option_helpers.option_to_value(card_id_param, 0),
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
  event: StateChange,
  project_name: String,
  user_name: String,
) -> String {
  let father = format_father_link(event)
  let from_state = option.unwrap(event_from_state_string(event), "(created)")
  let to_state = event_to_state_string(event)

  text
  |> string.replace("{{father}}", father)
  |> string.replace("{{from_state}}", from_state)
  |> string.replace("{{to_state}}", to_state)
  |> string.replace("{{project}}", project_name)
  |> string.replace("{{user}}", user_name)
}

fn format_father_link(event: StateChange) -> String {
  let resource_id = event_resource_id(event)

  case event_resource_type(event) {
    "task" ->
      "[Task #"
      <> int.to_string(resource_id)
      <> "](/tasks/"
      <> int.to_string(resource_id)
      <> ")"
    _ ->
      "[Card #"
      <> int.to_string(resource_id)
      <> "](/cards/"
      <> int.to_string(resource_id)
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

fn event_resource_type(event: StateChange) -> String {
  case event {
    TaskChange(..) -> "task"
    CardChange(..) -> "card"
  }
}

fn event_resource_id(event: StateChange) -> Int {
  case event {
    TaskChange(ctx: ctx, ..) -> ctx.task_id
    CardChange(card_id: card_id, ..) -> card_id
  }
}

fn event_project_id(event: StateChange) -> Int {
  case event {
    TaskChange(ctx: ctx, ..) -> ctx.project_id
    CardChange(project_id: project_id, ..) -> project_id
  }
}

fn event_org_id(event: StateChange) -> Int {
  case event {
    TaskChange(ctx: ctx, ..) -> ctx.org_id
    CardChange(org_id: org_id, ..) -> org_id
  }
}

fn event_user_id(event: StateChange) -> Int {
  case event {
    TaskChange(user_id: user_id, ..) -> user_id
    CardChange(user_id: user_id, ..) -> user_id
  }
}

fn event_user_triggered(event: StateChange) -> Bool {
  case event {
    TaskChange(user_triggered: user_triggered, ..) -> user_triggered
    CardChange(user_triggered: user_triggered, ..) -> user_triggered
  }
}

// Justification: nested case improves clarity for branching logic.
fn event_task_type_id(event: StateChange) -> option.Option(Int) {
  case event {
    TaskChange(ctx: ctx, ..) ->
      case ctx.type_id {
        id if id > 0 -> option.Some(id)
        _ -> option.None
      }
    CardChange(..) -> option.None
  }
}

fn event_card_id(event: StateChange) -> option.Option(Int) {
  case event {
    TaskChange(ctx: ctx, ..) -> ctx.card_id
    CardChange(..) -> option.None
  }
}

fn event_to_state_string(event: StateChange) -> String {
  case event {
    TaskChange(to_state: to_state, ..) -> to_state
    CardChange(to_state: to_state, ..) -> to_state
  }
}

fn event_from_state_string(event: StateChange) -> option.Option(String) {
  case event {
    TaskChange(from_state: from_state, ..) -> from_state
    CardChange(from_state: from_state, ..) -> from_state
  }
}
