//// Automation domain types.
////
//// Automations create available Pool work from supported system events. This
//// module keeps the product contract typed so due dates, subtree scopes, and
//// multi-template fan-out cannot accidentally become first-class triggers.

import domain/card
import domain/task_status
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
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
  TaskCompleted(task_type_id: Option(Int))
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
  InvalidMigratedData
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
  CreatedTask(task_id: Int)
  Failed(reason: RuleExecutionError)
}

pub type RuleExecutionError {
  TaskTemplateInvalid
  TaskCreateFailed
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
}

pub fn task_transition_trigger(
  from_state: Option(task_status.TaskPhase),
  to_state: task_status.TaskPhase,
  task_type_id: Option(Int),
) -> Result(AutomationTrigger, TriggerParseError) {
  case from_state, to_state {
    None, task_status.Available -> Ok(TaskCreated(task_type_id))
    _, task_status.Claimed(_) -> Ok(TaskClaimed(task_type_id))
    Some(task_status.Claimed(_)), task_status.Available ->
      Ok(TaskReleased(task_type_id))
    _, task_status.Done -> Ok(TaskCompleted(task_type_id))
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
    TaskCompleted(_) -> "task_completed"
    CardActivated(_) -> "card_activated"
    CardClosed(_) -> "card_closed"
  }
}

pub fn trigger_from_kind(
  kind: String,
  task_type_id: Option(Int),
) -> Result(AutomationTrigger, TriggerKindParseError) {
  case kind {
    "task_created" -> Ok(TaskCreated(task_type_id))
    "task_claimed" -> Ok(TaskClaimed(task_type_id))
    "task_released" -> Ok(TaskReleased(task_type_id))
    "task_completed" -> Ok(TaskCompleted(task_type_id))
    "card_activated" -> Ok(CardActivated(AnyCard))
    "card_closed" -> Ok(CardClosed(AnyCard))
    other -> Error(UnknownTriggerKind(other))
  }
}

pub fn trigger_resource_type(trigger: AutomationTrigger) -> String {
  case trigger {
    TaskCreated(_) | TaskClaimed(_) | TaskReleased(_) | TaskCompleted(_) ->
      "task"
    CardActivated(_) | CardClosed(_) -> "card"
  }
}

pub fn trigger_to_state_string(trigger: AutomationTrigger) -> String {
  case trigger {
    TaskCreated(_) | TaskReleased(_) -> "available"
    TaskClaimed(_) -> "claimed"
    TaskCompleted(_) -> task_status.task_status_to_string(task_status.Done)
    CardActivated(_) -> "en_curso"
    CardClosed(_) -> "cerrada"
  }
}

pub fn trigger_task_type_id(trigger: AutomationTrigger) -> Option(Int) {
  case trigger {
    TaskCreated(task_type_id)
    | TaskClaimed(task_type_id)
    | TaskReleased(task_type_id)
    | TaskCompleted(task_type_id) -> task_type_id
    CardActivated(_) | CardClosed(_) -> None
  }
}

pub fn available_template_variables(trigger: AutomationTrigger) -> List(String) {
  let common = ["origin", "trigger", "project", "user"]
  let specific = case trigger {
    TaskCreated(_) | TaskClaimed(_) | TaskReleased(_) | TaskCompleted(_) -> [
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
  let allowed = available_template_variables(trigger)
  extract_variables(text)
  |> list.any(fn(variable) { !list.contains(allowed, variable) })
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
