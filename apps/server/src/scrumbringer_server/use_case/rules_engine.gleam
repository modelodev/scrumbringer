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

import domain/automation
import domain/card as domain_card
import domain/task/state as task_state
import envoy
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/rules_templates

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
    <> event_task_type_label(event)
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
/// Task and card state values stay typed inside the engine. Conversion to
/// strings happens only at repository, logging, and template boundaries.
pub type StateChange {
  TaskChange(
    ctx: TaskContext,
    from_state: option.Option(task_state.TaskExecutionState),
    to_state: task_state.TaskExecutionState,
    user_id: Int,
    user_triggered: Bool,
  )
  CardChange(
    card_id: Int,
    project_id: Int,
    org_id: Int,
    from_state: option.Option(domain_card.CardPhase),
    to_state: domain_card.CardPhase,
    user_id: Int,
    user_triggered: Bool,
  )
}

/// Result of evaluating a single rule.
pub type RuleResult {
  RuleResult(rule_id: Int, outcome: automation.AutomationProcessResult)
}

/// Error during rule evaluation.
pub type RuleEngineError {
  DbError(pog.QueryError)
  UnsupportedAutomationTrigger
}

type TaskTemplateContext {
  TaskTemplateContext(title: String, type_name: String)
}

type CardTemplateContext {
  CardTemplateContext(title: String, depth: Int)
}

// =============================================================================
// Event Builders
// =============================================================================

/// Build a state change event for a task transition.
pub fn task_trigger(
  ctx: TaskContext,
  user_id: Int,
  from_state: option.Option(task_state.TaskExecutionState),
  to_state: task_state.TaskExecutionState,
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
pub fn card_trigger(
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: option.Option(domain_card.CardPhase),
  to_state: domain_card.CardPhase,
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
  log("Applied: " <> int.to_string(list.length(applied)) <> " rule(s)")
}

fn is_rule_applied(result: RuleResult) -> Bool {
  case result.outcome {
    automation.Executed(_) -> True
    automation.NoMatchingRule
    | automation.Skipped(_)
    | automation.DuplicateEvent -> False
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
    UnsupportedAutomationTrigger -> "unsupported automation trigger"
  }
}

// =============================================================================
// Internal types for SQL mapping
// =============================================================================

type MatchingRule {
  MatchingRule(id: Int, name: String)
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
    version: Int,
    created_by: Int,
    created_at: String,
    execution_order: Int,
  )
}

type RuleExecutionReservation {
  ReservedExecution(id: Int)
  DuplicateExecution
}

// =============================================================================
// Internal Functions
// =============================================================================

fn find_matching_rules(
  db: pog.Connection,
  event: StateChange,
) -> Result(List(MatchingRule), RuleEngineError) {
  use trigger <- result.try(event_trigger(event))
  let trigger_kind = automation.trigger_kind(trigger)
  let task_type_param = task_type_filter_value(trigger)
  use card_depth_param <- result.try(event_card_depth(db, event))

  case
    sql.rules_find_matching(
      db,
      trigger_kind,
      event_project_id(event),
      event_org_id(event),
      task_type_param,
      card_depth_param,
    )
  {
    Ok(returned) -> list.try_map(returned.rows, matching_rule_from_row)

    Error(e) -> Error(DbError(e))
  }
}

fn matching_rule_from_row(
  row: sql.RulesFindMatchingRow,
) -> Result(MatchingRule, RuleEngineError) {
  Ok(MatchingRule(id: row.id, name: row.name))
}

fn evaluate_single_rule(
  db: pog.Connection,
  rule: MatchingRule,
  event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  evaluate_rule_templates(db, rule, event)
}

fn evaluate_rule_templates(
  db: pog.Connection,
  rule: MatchingRule,
  event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  use templates <- result.try(get_rule_templates(db, rule.id))

  log("  Found " <> int.to_string(list.length(templates)) <> " template")

  case templates {
    [] -> apply_rule_without_templates(db, rule, event)
    [template] -> apply_rule_with_template(db, rule, template, event)
    [_, _, ..] -> apply_rule_with_invalid_template_selection(rule)
  }
}

fn apply_rule_without_templates(
  _db: pog.Connection,
  rule: MatchingRule,
  _event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  log("  Suppressed: rule has no template")

  Ok(RuleResult(
    rule.id,
    automation.Skipped(automation.RuleRequiresReview(automation.TemplateMissing)),
  ))
}

fn apply_rule_with_invalid_template_selection(
  rule: MatchingRule,
) -> Result(RuleResult, RuleEngineError) {
  log("  Suppressed: rule has multiple selected templates")

  Ok(RuleResult(
    rule.id,
    automation.Skipped(automation.RuleRequiresReview(
      automation.MultipleTemplatesSelected,
    )),
  ))
}

fn apply_rule_with_template(
  db: pog.Connection,
  rule: MatchingRule,
  template: ExecutionTemplate,
  event: StateChange,
) -> Result(RuleResult, RuleEngineError) {
  use trigger <- result.try(event_trigger(event))
  let event_key =
    automation.trigger_to_event_key(trigger, event_resource_id(event))

  pog.transaction(db, fn(tx) {
    use reservation <- result.try(reserve_execution(
      tx,
      rule.id,
      event_key,
      event,
      template,
    ))

    case reservation {
      DuplicateExecution -> {
        log("  Suppressed: already executed for this event")
        Ok(RuleResult(rule.id, automation.DuplicateEvent))
      }
      ReservedExecution(execution_id) -> {
        use task_id <- result.try(create_task_from_template(
          tx,
          rule.id,
          template,
          event,
          get_project_name(tx, event_project_id(event)),
          get_user_name(tx, event_user_id(event)),
        ))

        use _ <- result.try(mark_execution_created_task(
          tx,
          execution_id,
          task_id,
        ))

        log("  Applied: created task #" <> int.to_string(task_id))
        Ok(RuleResult(rule.id, automation.Executed(execution_id)))
      }
    }
  })
  |> result.map_error(transaction_error_to_rule_engine_error)
}

fn transaction_error_to_rule_engine_error(
  error: pog.TransactionError(RuleEngineError),
) -> RuleEngineError {
  case error {
    pog.TransactionQueryError(error) -> DbError(error)
    pog.TransactionRolledBack(error) -> error
  }
}

fn get_rule_templates(
  db: pog.Connection,
  rule_id: Int,
) -> Result(List(ExecutionTemplate), RuleEngineError) {
  case sql.rules_get_templates_for_execution(db, rule_id) {
    Ok(returned) ->
      returned.rows
      |> list.try_map(execution_template_from_row)

    Error(e) -> Error(DbError(e))
  }
}

fn execution_template_from_row(
  row: sql.RulesGetTemplatesForExecutionRow,
) -> Result(ExecutionTemplate, RuleEngineError) {
  Ok(ExecutionTemplate(
    id: row.id,
    org_id: row.org_id,
    project_id: option_helpers.int_to_option(row.project_id),
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    type_id: row.type_id,
    priority: row.priority,
    version: row.version,
    created_by: row.created_by,
    created_at: row.created_at,
    execution_order: row.execution_order,
  ))
}

fn create_task_from_template(
  db: pog.Connection,
  rule_id: Int,
  template: ExecutionTemplate,
  event: StateChange,
  project_name: String,
  user_name: String,
) -> Result(Int, RuleEngineError) {
  let origin =
    rules_templates.format_origin_link(
      event_resource_type(event),
      event_resource_id(event),
    )
  let context =
    template_event_context(db, event, origin, project_name, user_name)
  let title = rules_templates.substitute(template.name, context)
  let description =
    rules_templates.substitute(template_description_text(template), context)

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
  // $1=type_id, $2=project_id, $3=title, $4=description, $5=priority,
  // $6=created_by, $7=card_id, $8=parent_card_id, $9=rule_id
  case
    sql.tasks_create(
      db,
      template.type_id,
      event_project_id(event),
      title,
      description,
      template.priority,
      event_user_id(event),
      card_id_create_value(card_id_param),
      no_task_parent_card_id,
      rule_id,
    )
  {
    Ok(pog.Returned(rows: rows, ..)) -> {
      case persisted_field.query_row(rows) {
        Ok(row) -> {
          log("    Created task #" <> int.to_string(row.id))
          Ok(row.id)
        }
        Error(e) -> {
          log("    Error: task creation returned no rows")
          Error(DbError(e))
        }
      }
    }
    Error(e) -> {
      log("    Error creating task: " <> debug_error(DbError(e)))
      Error(DbError(e))
    }
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

fn template_event_context(
  db: pog.Connection,
  event: StateChange,
  origin: String,
  project_name: String,
  user_name: String,
) -> rules_templates.EventContext {
  let #(task_title, task_type) = task_template_values(db, event)
  let #(card_title, card_level) = card_template_values(db, event)

  rules_templates.EventContext(
    origin: origin,
    trigger: event_to_state_string(event),
    project_name: project_name,
    user_name: user_name,
    task_title: task_title,
    task_type: task_type,
    card_title: card_title,
    card_level: card_level,
  )
}

fn task_template_values(
  db: pog.Connection,
  event: StateChange,
) -> #(String, String) {
  case event {
    TaskChange(ctx: ctx, ..) ->
      case get_task_template_context(db, ctx.task_id) {
        Ok(TaskTemplateContext(title: title, type_name: type_name)) -> #(
          title,
          type_name,
        )
        Error(_) -> #("", "")
      }
    CardChange(..) -> #("", "")
  }
}

fn card_template_values(
  db: pog.Connection,
  event: StateChange,
) -> #(String, String) {
  case event {
    CardChange(card_id: card_id, ..) ->
      case get_card_template_context(db, card_id) {
        Ok(CardTemplateContext(title: title, depth: depth)) -> #(
          title,
          int.to_string(depth),
        )
        Error(_) -> #("", "")
      }
    TaskChange(..) -> #("", "")
  }
}

fn get_task_template_context(
  db: pog.Connection,
  task_id: Int,
) -> Result(TaskTemplateContext, pog.QueryError) {
  let decoder = {
    use title <- decode.field(0, decode.string)
    use type_name <- decode.field(1, decode.string)
    decode.success(TaskTemplateContext(title: title, type_name: type_name))
  }

  case
    pog.query(
      "\nselect t.title, tt.name\nfrom tasks t\njoin task_types tt on tt.id = t.type_id\nwhere t.id = $1",
    )
    |> pog.parameter(pog.int(task_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row)
    Ok(_) -> Ok(TaskTemplateContext(title: "", type_name: ""))
    Error(error) -> Error(error)
  }
}

fn get_card_template_context(
  db: pog.Connection,
  card_id: Int,
) -> Result(CardTemplateContext, pog.QueryError) {
  let decoder = {
    use title <- decode.field(0, decode.string)
    use depth <- decode.field(1, decode.int)
    decode.success(CardTemplateContext(title: title, depth: depth))
  }

  case
    pog.query(
      "\nwith recursive ancestors as (\n  select id, parent_card_id, 1::int as depth\n  from cards\n  where id = $1\n  union all\n  select parent.id, parent.parent_card_id, child.depth + 1\n  from cards parent\n  join ancestors child on child.parent_card_id = parent.id\n), target as (\n  select title\n  from cards\n  where id = $1\n)\nselect target.title, max(ancestors.depth)::int\nfrom target, ancestors\ngroup by target.title",
    )
    |> pog.parameter(pog.int(card_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row)
    Ok(_) -> Ok(CardTemplateContext(title: "", depth: 0))
    Error(error) -> Error(error)
  }
}

fn reserve_execution(
  db: pog.Connection,
  rule_id: Int,
  event_key: String,
  event: StateChange,
  template: ExecutionTemplate,
) -> Result(RuleExecutionReservation, RuleEngineError) {
  case
    sql.rule_executions_log(
      db,
      rule_id,
      event_key,
      execution_task_id(event),
      execution_card_id(event),
      "applied",
      "",
      event_user_id(event),
      template.id,
      template.version,
      no_created_task_id,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(ReservedExecution(row.id))
    Ok(pog.Returned(rows: [], ..)) -> Ok(DuplicateExecution)
    Error(e) -> Error(DbError(e))
  }
}

fn mark_execution_created_task(
  db: pog.Connection,
  execution_id: Int,
  created_task_id: Int,
) -> Result(Nil, RuleEngineError) {
  case
    sql.rule_executions_mark_created_task(db, execution_id, created_task_id)
  {
    Ok(pog.Returned(rows: rows, ..)) ->
      case persisted_field.query_row(rows) {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(DbError(e))
      }
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

fn execution_task_id(event: StateChange) -> Int {
  case event {
    TaskChange(ctx: ctx, ..) -> ctx.task_id
    CardChange(..) -> no_execution_resource_id
  }
}

fn execution_card_id(event: StateChange) -> Int {
  case event {
    TaskChange(..) -> no_execution_resource_id
    CardChange(card_id: card_id, ..) -> card_id
  }
}

const no_execution_resource_id = 0

const no_created_task_id = 0

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

fn task_type_filter_value(trigger: automation.AutomationTrigger) -> Int {
  option_helpers.option_to_value(
    automation.trigger_task_type_id(trigger),
    no_task_type_filter_value,
  )
}

const no_task_type_filter_value = 0

fn event_task_type_label(event: StateChange) -> String {
  case event_task_type_id(event) {
    option.Some(type_id) -> int.to_string(type_id)
    option.None -> "none"
  }
}

fn event_card_id(event: StateChange) -> option.Option(Int) {
  case event {
    TaskChange(ctx: ctx, ..) -> ctx.card_id
    CardChange(..) -> option.None
  }
}

fn event_card_depth(
  db: pog.Connection,
  event: StateChange,
) -> Result(Int, RuleEngineError) {
  case event {
    TaskChange(..) -> Ok(no_card_depth_scope)
    CardChange(card_id: card_id, ..) ->
      case get_card_template_context(db, card_id) {
        Ok(CardTemplateContext(depth: depth, ..)) -> Ok(depth)
        Error(error) -> Error(DbError(error))
      }
  }
}

const no_card_depth_scope = 0

fn event_trigger(
  event: StateChange,
) -> Result(automation.AutomationTrigger, RuleEngineError) {
  case event {
    TaskChange(from_state: from_state, to_state: to_state, ..) ->
      automation.task_transition_trigger(
        from_state,
        to_state,
        event_task_type_id(event),
      )
      |> result.map_error(fn(_) { UnsupportedAutomationTrigger })

    CardChange(to_state: to_state, ..) ->
      automation.card_transition_trigger(to_state, automation.AnyCard)
      |> result.map_error(fn(_) { UnsupportedAutomationTrigger })
  }
}

fn card_id_create_value(card_id: option.Option(Int)) -> Int {
  option_helpers.option_to_value(card_id, no_card_id_create_value)
}

const no_card_id_create_value = 0

const no_task_parent_card_id = 0

fn event_to_state_string(event: StateChange) -> String {
  case event {
    TaskChange(to_state: to_state, ..) -> task_state_event_string(to_state)
    CardChange(to_state: to_state, ..) -> domain_card.state_to_string(to_state)
  }
}

fn task_state_event_string(state: task_state.TaskExecutionState) -> String {
  case state {
    task_state.Available -> "available"
    task_state.Claimed(_, _, task_state.Ongoing) -> "ongoing"
    task_state.Claimed(_, _, task_state.Taken) -> "claimed"
    task_state.Closed(task_state.Done, _, _) -> "completed"
    task_state.Closed(_, _, _) -> "closed"
  }
}

fn template_description_text(template: ExecutionTemplate) -> String {
  case template.description {
    option.Some(description) -> description
    option.None -> ""
  }
}
