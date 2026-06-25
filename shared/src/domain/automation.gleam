//// Automation domain types.
////
//// Automations create available Pool work from supported system events. This
//// module keeps the product contract typed so due dates, subtree scopes, and
//// multi-template fan-out cannot accidentally become first-class triggers.

import domain/card
import domain/task/state as task_state
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub opaque type CardDepth {
  CardDepth(Int)
}

pub type CardDepthError {
  InvalidCardDepth(Int)
}

pub fn card_depth_from_int(value: Int) -> Result(CardDepth, CardDepthError) {
  case value > 0 {
    True -> Ok(CardDepth(value))
    False -> Error(InvalidCardDepth(value))
  }
}

pub fn card_depth_to_int(depth: CardDepth) -> Int {
  let CardDepth(value) = depth
  value
}

pub type CardAutomationScope {
  AnyCard
  AtDepth(CardDepth)
}

pub type AutomationTrigger {
  TaskCreated(task_type_id: Option(Int))
  TaskClaimed(task_type_id: Option(Int))
  TaskReleased(task_type_id: Option(Int))
  TaskClosed(task_type_id: Option(Int))
  CardActivated(scope: CardAutomationScope)
  CardClosed(scope: CardAutomationScope)
}

pub type AutomationAction {
  CreateTask(template_id: Int)
}

pub type AutomationEngineStatus {
  EngineActive
  EnginePaused
}

pub type AutomationRuleStatus {
  Active
  Paused
  RequiresReview(reason: RuleReviewReason)
}

pub type RuleReviewReason {
  TemplateMissing
  TaskTypeMissing
  CardDepthNoLongerExists
  MultipleTemplatesSelected
}

pub opaque type AutomationRule {
  AutomationRule(
    id: Int,
    engine_id: Int,
    trigger: AutomationTrigger,
    action: AutomationAction,
    status: AutomationRuleStatus,
  )
}

pub type RuleDraft {
  RuleDraft(
    engine_id: Option(Int),
    trigger: Option(AutomationTrigger),
    template_id: Option(Int),
  )
}

pub opaque type ValidRuleDraft {
  ValidRuleDraft(
    engine_id: Int,
    trigger: AutomationTrigger,
    action: AutomationAction,
  )
}

pub type RuleDraftValidationError {
  MissingEngine
  MissingTrigger
  MissingTemplate
  InvalidTemplateId(Int)
}

pub fn validate_rule_draft(
  draft: RuleDraft,
) -> Result(ValidRuleDraft, RuleDraftValidationError) {
  use engine_id <- result_try_option(draft.engine_id, MissingEngine)
  use trigger <- result_try_option(draft.trigger, MissingTrigger)
  use template_id <- result_try_option(draft.template_id, MissingTemplate)

  case template_id > 0 {
    True ->
      Ok(ValidRuleDraft(
        engine_id: engine_id,
        trigger: trigger,
        action: CreateTask(template_id),
      ))
    False -> Error(InvalidTemplateId(template_id))
  }
}

pub fn create_rule(
  id: Int,
  valid: ValidRuleDraft,
  status: AutomationRuleStatus,
) -> AutomationRule {
  let ValidRuleDraft(engine_id: engine_id, trigger: trigger, action: action) =
    valid

  AutomationRule(
    id: id,
    engine_id: engine_id,
    trigger: trigger,
    action: action,
    status: status,
  )
}

pub fn rule_id(rule: AutomationRule) -> Int {
  let AutomationRule(id: id, ..) = rule
  id
}

pub fn rule_engine_id(rule: AutomationRule) -> Int {
  let AutomationRule(engine_id: engine_id, ..) = rule
  engine_id
}

pub fn rule_trigger(rule: AutomationRule) -> AutomationTrigger {
  let AutomationRule(trigger: trigger, ..) = rule
  trigger
}

pub fn rule_action(rule: AutomationRule) -> AutomationAction {
  let AutomationRule(action: action, ..) = rule
  action
}

pub fn rule_status(rule: AutomationRule) -> AutomationRuleStatus {
  let AutomationRule(status: status, ..) = rule
  status
}

pub fn valid_rule_draft_engine_id(valid: ValidRuleDraft) -> Int {
  let ValidRuleDraft(engine_id: engine_id, ..) = valid
  engine_id
}

pub fn valid_rule_draft_trigger(valid: ValidRuleDraft) -> AutomationTrigger {
  let ValidRuleDraft(trigger: trigger, ..) = valid
  trigger
}

pub fn valid_rule_draft_action(valid: ValidRuleDraft) -> AutomationAction {
  let ValidRuleDraft(action: action, ..) = valid
  action
}

pub fn action_template_id(action: AutomationAction) -> Int {
  case action {
    CreateTask(template_id) -> template_id
  }
}

pub fn status_to_active(status: AutomationRuleStatus) -> Bool {
  case status {
    Active -> True
    Paused | RequiresReview(_) -> False
  }
}

pub fn active_to_rule_status(active: Bool) -> AutomationRuleStatus {
  case active {
    True -> Active
    False -> Paused
  }
}

pub type AutomationProcessResult {
  Executed(execution_id: Int)
  NoMatchingRule
  Skipped(reason: AutomationSkipReason)
  DuplicateEvent
}

pub type AutomationSkipReason {
  SkippedEnginePaused
  RulePaused
  RuleRequiresReview(reason: RuleReviewReason)
  CreatedByAutomation
}

pub type RuleExecutionOutcome {
  AppliedRuleExecution
  SuppressedRuleExecution(reason: Option(RuleSuppressionReason))
  UnknownRuleExecution(
    raw: String,
    suppression_reason: Option(RuleSuppressionReason),
  )
}

pub type RuleSuppressionReason {
  IdempotentSuppression
  NotUserTriggeredSuppression
  NotMatchingSuppression
  InactiveSuppression
  UnknownSuppressionReason(raw: String)
}

pub type TaskCreationSource {
  Manual(user_id: Int)
  Automation(execution_id: Int)
}

pub type RuleTriggerSource {
  UserAction(user_id: Int)
}

pub type EventId {
  EventId(value: String)
}

pub fn event_id_to_string(event_id: EventId) -> String {
  let EventId(value) = event_id
  value
}

pub type TriggerParseError {
  UnsupportedTransition
}

pub type TriggerKindParseError {
  UnknownTriggerKind(String)
  InvalidTriggerCardDepth(Int)
}

pub fn task_transition_trigger(
  from_state: Option(task_state.TaskExecutionState),
  to_state: task_state.TaskExecutionState,
  task_type_id: Option(Int),
) -> Result(AutomationTrigger, TriggerParseError) {
  case from_state, to_state {
    None, task_state.Available -> Ok(TaskCreated(task_type_id))
    _, task_state.Claimed(_, _, _) -> Ok(TaskClaimed(task_type_id))
    Some(task_state.Claimed(_, _, _)), task_state.Available ->
      Ok(TaskReleased(task_type_id))
    _, task_state.Closed(task_state.ClosedByClaimant, _, _) ->
      Ok(TaskClosed(task_type_id))
    _, _ -> Error(UnsupportedTransition)
  }
}

pub fn card_transition_trigger(
  to_state: card.CardPhase,
  scope: CardAutomationScope,
) -> Result(AutomationTrigger, TriggerParseError) {
  case to_state {
    card.Active -> Ok(CardActivated(scope))
    card.Closed -> Ok(CardClosed(scope))
    card.Draft -> Error(UnsupportedTransition)
  }
}

pub fn trigger_to_event_key(
  trigger: AutomationTrigger,
  resource_id: Int,
) -> String {
  trigger_kind(trigger) <> ":" <> int.to_string(resource_id)
}

pub fn trigger_kind(trigger: AutomationTrigger) -> String {
  case trigger {
    TaskCreated(_) -> "task_created"
    TaskClaimed(_) -> "task_claimed"
    TaskReleased(_) -> "task_released"
    // Historical wire kind retained for existing rule payloads.
    TaskClosed(_) -> "task_closed"
    CardActivated(_) -> "card_activated"
    CardClosed(_) -> "card_closed"
  }
}

pub fn trigger_from_kind(
  kind: String,
  task_type_id: Option(Int),
  card_depth: Option(Int),
) -> Result(AutomationTrigger, TriggerKindParseError) {
  case kind {
    "task_created" -> Ok(TaskCreated(task_type_id))
    "task_claimed" -> Ok(TaskClaimed(task_type_id))
    "task_released" -> Ok(TaskReleased(task_type_id))
    "task_closed" -> Ok(TaskClosed(task_type_id))
    "card_activated" -> {
      use scope <- result.try(scope_from_depth(card_depth))
      Ok(CardActivated(scope))
    }
    "card_closed" -> {
      use scope <- result.try(scope_from_depth(card_depth))
      Ok(CardClosed(scope))
    }
    other -> Error(UnknownTriggerKind(other))
  }
}

fn scope_from_depth(
  card_depth: Option(Int),
) -> Result(CardAutomationScope, TriggerKindParseError) {
  case card_depth {
    Some(depth) ->
      case card_depth_from_int(depth) {
        Ok(valid) -> Ok(AtDepth(valid))
        Error(_) -> Error(InvalidTriggerCardDepth(depth))
      }
    None -> Ok(AnyCard)
  }
}

pub fn trigger_resource_type(trigger: AutomationTrigger) -> String {
  case trigger {
    TaskCreated(_) | TaskClaimed(_) | TaskReleased(_) | TaskClosed(_) -> "task"
    CardActivated(_) | CardClosed(_) -> "card"
  }
}

pub fn trigger_to_state_string(trigger: AutomationTrigger) -> String {
  case trigger {
    TaskCreated(_) | TaskReleased(_) -> "available"
    TaskClaimed(_) -> "claimed"
    TaskClosed(_) -> "closed"
    CardActivated(_) -> "en_curso"
    CardClosed(_) -> "cerrada"
  }
}

pub fn trigger_task_type_id(trigger: AutomationTrigger) -> Option(Int) {
  case trigger {
    TaskCreated(task_type_id)
    | TaskClaimed(task_type_id)
    | TaskReleased(task_type_id)
    | TaskClosed(task_type_id) -> task_type_id
    CardActivated(_) | CardClosed(_) -> None
  }
}

pub fn trigger_card_depth(trigger: AutomationTrigger) -> Option(Int) {
  let scope = case trigger {
    CardActivated(scope) | CardClosed(scope) -> Some(scope)
    TaskCreated(_) | TaskClaimed(_) | TaskReleased(_) | TaskClosed(_) -> None
  }

  case scope {
    Some(AtDepth(depth)) -> Some(card_depth_to_int(depth))
    Some(AnyCard) | None -> None
  }
}

pub fn trigger_to_db_values(
  trigger: AutomationTrigger,
) -> #(String, Int, Int, String) {
  let task_type_id = case trigger_task_type_id(trigger) {
    Some(id) -> id
    None -> 0
  }
  let card_depth = case trigger_card_depth(trigger) {
    Some(depth) -> depth
    None -> 0
  }

  #(
    trigger_resource_type(trigger),
    task_type_id,
    card_depth,
    trigger_to_state_string(trigger),
  )
}

pub fn rule_execution_outcome_from_strings(
  outcome: String,
  suppression_reason: String,
) -> RuleExecutionOutcome {
  let reason = rule_suppression_reason_from_string(suppression_reason)

  case outcome {
    "applied" -> AppliedRuleExecution
    "suppressed" -> SuppressedRuleExecution(reason)
    other -> UnknownRuleExecution(raw: other, suppression_reason: reason)
  }
}

pub fn rule_execution_outcome_to_string(outcome: RuleExecutionOutcome) -> String {
  case outcome {
    AppliedRuleExecution -> "applied"
    SuppressedRuleExecution(_) -> "suppressed"
    UnknownRuleExecution(raw:, ..) -> raw
  }
}

pub fn rule_execution_suppression_reason_name(
  outcome: RuleExecutionOutcome,
) -> Option(String) {
  case outcome {
    SuppressedRuleExecution(Some(reason))
    | UnknownRuleExecution(suppression_reason: Some(reason), ..) ->
      Some(rule_suppression_reason_to_string(reason))

    AppliedRuleExecution
    | SuppressedRuleExecution(None)
    | UnknownRuleExecution(suppression_reason: None, ..) -> None
  }
}

pub fn rule_suppression_reason_to_string(
  reason: RuleSuppressionReason,
) -> String {
  case reason {
    IdempotentSuppression -> "idempotent"
    NotUserTriggeredSuppression -> "not_user_triggered"
    NotMatchingSuppression -> "not_matching"
    InactiveSuppression -> "inactive"
    UnknownSuppressionReason(raw) -> raw
  }
}

fn rule_suppression_reason_from_string(
  raw: String,
) -> Option(RuleSuppressionReason) {
  case raw {
    "" -> None
    "idempotent" -> Some(IdempotentSuppression)
    "not_user_triggered" -> Some(NotUserTriggeredSuppression)
    "not_matching" -> Some(NotMatchingSuppression)
    "inactive" -> Some(InactiveSuppression)
    other -> Some(UnknownSuppressionReason(other))
  }
}

pub fn available_template_variables(trigger: AutomationTrigger) -> List(String) {
  let common = ["origin", "trigger", "project", "user"]
  let specific = case trigger {
    TaskCreated(_) | TaskClaimed(_) | TaskReleased(_) | TaskClosed(_) -> [
      "task_title",
      "task_type",
    ]
    CardActivated(_) | CardClosed(_) -> ["card_title", "card_level"]
  }

  list.append(common, specific)
}

pub fn template_uses_unknown_variables(
  text: String,
  trigger: AutomationTrigger,
) -> Bool {
  case unknown_template_variables(text, trigger) {
    [] -> False
    _ -> True
  }
}

pub fn unknown_template_variables(
  text: String,
  trigger: AutomationTrigger,
) -> List(String) {
  let allowed = available_template_variables(trigger)
  extract_variables(text)
  |> list.filter(fn(variable) { !list.contains(allowed, variable) })
}

fn extract_variables(text: String) -> List(String) {
  text
  |> string.split("{{")
  |> list.drop(1)
  |> list.filter_map(fn(part) {
    case string.split(part, "}}") {
      [variable, ..] -> Ok(string.trim(variable))
      _ -> Error(Nil)
    }
  })
}

fn result_try_option(
  value: Option(a),
  error: e,
  next: fn(a) -> Result(b, e),
) -> Result(b, e) {
  case value {
    Some(inner) -> next(inner)
    None -> Error(error)
  }
}
