import domain/automation
import domain/card
import domain/task/state as task_state
import gleam/option.{None, Some}

pub fn card_depth_must_be_positive_test() {
  let assert Ok(depth) = automation.card_depth_from_int(2)
  let assert 2 = automation.card_depth_to_int(depth)
  let assert Error(automation.InvalidCardDepth(0)) =
    automation.card_depth_from_int(0)
}

pub fn task_transitions_map_to_supported_triggers_test() {
  let assert Ok(automation.TaskCreated(Some(7))) =
    automation.task_transition_trigger(None, task_state.Available, Some(7))

  let assert Ok(automation.TaskClaimed(Some(7))) =
    automation.task_transition_trigger(
      Some(task_state.Available),
      task_state.Claimed(1, "2026-01-15T10:00:00Z", task_state.Taken),
      Some(7),
    )

  let assert Ok(automation.TaskReleased(Some(7))) =
    automation.task_transition_trigger(
      Some(task_state.Claimed(1, "2026-01-15T10:00:00Z", task_state.Taken)),
      task_state.Available,
      Some(7),
    )

  let assert Ok(automation.TaskClosed(Some(7))) =
    automation.task_transition_trigger(
      Some(task_state.Claimed(1, "2026-01-15T10:00:00Z", task_state.Taken)),
      task_state.Closed(task_state.ClosedByClaimant, "2026-01-15T10:30:00Z", 1),
      Some(7),
    )
}

pub fn card_transitions_map_to_supported_triggers_test() {
  let assert Ok(depth) = automation.card_depth_from_int(3)

  let assert Ok(automation.CardActivated(automation.AnyCard)) =
    automation.card_transition_trigger(card.Active, automation.AnyCard)

  let assert Ok(automation.CardClosed(automation.AtDepth(_depth))) =
    automation.card_transition_trigger(card.Closed, automation.AtDepth(depth))

  let assert Error(automation.UnsupportedTransition) =
    automation.card_transition_trigger(card.Draft, automation.AnyCard)
}

pub fn event_keys_separate_different_facts_on_same_task_test() {
  let task_id = 42

  let created = automation.TaskCreated(None)
  let claimed = automation.TaskClaimed(None)
  let released = automation.TaskReleased(None)
  let done = automation.TaskClosed(None)

  let assert "task_created:42" =
    automation.trigger_to_event_key(created, task_id)
  let assert "task_claimed:42" =
    automation.trigger_to_event_key(claimed, task_id)
  let assert "task_released:42" =
    automation.trigger_to_event_key(released, task_id)
  let assert "task_closed:42" = automation.trigger_to_event_key(done, task_id)
}

pub fn rule_execution_outcome_parses_applied_without_reason_test() {
  let outcome = automation.rule_execution_outcome_from_strings("applied", "")

  let assert automation.AppliedRuleExecution = outcome
  let assert "applied" = automation.rule_execution_outcome_to_string(outcome)
  let assert None = automation.rule_execution_suppression_reason_name(outcome)
}

pub fn rule_execution_outcome_parses_suppressed_known_reason_test() {
  let outcome =
    automation.rule_execution_outcome_from_strings("suppressed", "idempotent")

  let assert automation.SuppressedRuleExecution(Some(
    automation.IdempotentSuppression,
  )) = outcome
  let assert "suppressed" = automation.rule_execution_outcome_to_string(outcome)
  let assert Some("idempotent") =
    automation.rule_execution_suppression_reason_name(outcome)
}

pub fn rule_execution_outcome_preserves_unknown_values_test() {
  let outcome =
    automation.rule_execution_outcome_from_strings("queued", "manual")

  let assert automation.UnknownRuleExecution(
    raw: "queued",
    suppression_reason: Some(automation.UnknownSuppressionReason("manual")),
  ) = outcome
  let assert "queued" = automation.rule_execution_outcome_to_string(outcome)
  let assert Some("manual") =
    automation.rule_execution_suppression_reason_name(outcome)
}

pub fn trigger_kind_round_trips_to_supported_trigger_test() {
  let assert Ok(automation.TaskCreated(Some(7))) =
    automation.trigger_from_kind("task_created", Some(7), None)
  let assert Ok(automation.TaskClaimed(Some(7))) =
    automation.trigger_from_kind("task_claimed", Some(7), None)
  let assert Ok(automation.TaskReleased(Some(7))) =
    automation.trigger_from_kind("task_released", Some(7), None)
  let assert Ok(automation.TaskClosed(Some(7))) =
    automation.trigger_from_kind("task_closed", Some(7), None)
  let assert Ok(automation.CardActivated(automation.AnyCard)) =
    automation.trigger_from_kind("card_activated", None, None)
  let assert Ok(automation.CardClosed(automation.AtDepth(depth))) =
    automation.trigger_from_kind("card_closed", None, Some(2))
  let assert 2 = automation.card_depth_to_int(depth)
  let assert Error(automation.InvalidTriggerCardDepth(0)) =
    automation.trigger_from_kind("card_activated", None, Some(0))
  let assert Error(automation.UnknownTriggerKind("task_due")) =
    automation.trigger_from_kind("task_due", None, None)
}

pub fn trigger_to_db_values_preserves_card_depth_scope_test() {
  let assert Ok(depth) = automation.card_depth_from_int(3)

  let assert #("card", 0, 3, "en_curso") =
    automation.trigger_to_db_values(
      automation.CardActivated(automation.AtDepth(depth)),
    )

  let assert #("card", 0, 0, "cerrada") =
    automation.trigger_to_db_values(automation.CardClosed(automation.AnyCard))
}

pub fn available_variables_exclude_removed_and_due_date_values_test() {
  let trigger = automation.TaskClosed(None)

  let assert False =
    automation.template_uses_unknown_variables(
      "{{origin}} {{trigger}} {{project}} {{user}} {{task_title}} {{task_type}}",
      trigger,
    )

  let assert True =
    automation.template_uses_unknown_variables("{{unknown}}", trigger)
  let assert True =
    automation.template_uses_unknown_variables("{{due_date}}", trigger)
}

pub fn template_variables_depend_on_trigger_family_test() {
  let task_trigger = automation.TaskClosed(None)
  let card_trigger = automation.CardActivated(automation.AnyCard)

  let assert False =
    automation.template_uses_unknown_variables(
      "{{origin}} {{task_title}} {{task_type}}",
      task_trigger,
    )
  let assert True =
    automation.template_uses_unknown_variables("{{card_title}}", task_trigger)

  let assert False =
    automation.template_uses_unknown_variables(
      "{{origin}} {{card_title}} {{card_level}}",
      card_trigger,
    )
  let assert True =
    automation.template_uses_unknown_variables("{{task_title}}", card_trigger)
}

pub fn unknown_template_variables_returns_concrete_blocking_variables_test() {
  let task_trigger = automation.TaskClosed(None)

  let assert ["card_title", "card_level", "due_date"] =
    automation.unknown_template_variables(
      "{{origin}} {{card_title}} {{card_level}} {{due_date}}",
      task_trigger,
    )
}

pub fn rule_draft_requires_engine_trigger_and_template_test() {
  let empty =
    automation.RuleDraft(engine_id: None, trigger: None, template_id: None)

  let assert Error(automation.MissingEngine) =
    automation.validate_rule_draft(empty)

  let no_trigger =
    automation.RuleDraft(
      engine_id: Some(1),
      trigger: None,
      template_id: Some(2),
    )

  let assert Error(automation.MissingTrigger) =
    automation.validate_rule_draft(no_trigger)

  let no_template =
    automation.RuleDraft(
      engine_id: Some(1),
      trigger: Some(automation.TaskClosed(None)),
      template_id: None,
    )

  let assert Error(automation.MissingTemplate) =
    automation.validate_rule_draft(no_template)
}

pub fn rule_draft_rejects_invalid_template_id_test() {
  let draft =
    automation.RuleDraft(
      engine_id: Some(1),
      trigger: Some(automation.TaskClosed(None)),
      template_id: Some(0),
    )

  let assert Error(automation.InvalidTemplateId(0)) =
    automation.validate_rule_draft(draft)
}

pub fn valid_rule_draft_creates_single_task_rule_test() {
  let draft =
    automation.RuleDraft(
      engine_id: Some(10),
      trigger: Some(automation.TaskClosed(Some(7))),
      template_id: Some(20),
    )

  let assert Ok(valid) = automation.validate_rule_draft(draft)
  let assert 10 = automation.valid_rule_draft_engine_id(valid)
  let assert automation.TaskClosed(Some(7)) =
    automation.valid_rule_draft_trigger(valid)
  let assert automation.CreateTask(20) =
    automation.valid_rule_draft_action(valid)

  let rule = automation.create_rule(30, valid, automation.Active)

  let assert 30 = automation.rule_id(rule)
  let assert 10 = automation.rule_engine_id(rule)
  let assert automation.TaskClosed(Some(7)) = automation.rule_trigger(rule)
  let assert automation.CreateTask(20) = automation.rule_action(rule)
  let assert automation.Active = automation.rule_status(rule)
}
