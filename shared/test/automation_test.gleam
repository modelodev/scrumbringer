import domain/automation
import domain/card
import domain/task_status
import gleam/option.{None, Some}

pub fn card_depth_must_be_positive_test() {
  let assert Ok(depth) = automation.card_depth_from_int(2)
  let assert 2 = automation.card_depth_to_int(depth)
  let assert Error(automation.InvalidCardDepth(0)) =
    automation.card_depth_from_int(0)
}

pub fn task_transitions_map_to_supported_triggers_test() {
  let assert Ok(automation.TaskCreated(Some(7))) =
    automation.task_transition_trigger(None, task_status.Available, Some(7))

  let assert Ok(automation.TaskClaimed(Some(7))) =
    automation.task_transition_trigger(
      Some(task_status.Available),
      task_status.Claimed(task_status.Taken),
      Some(7),
    )

  let assert Ok(automation.TaskReleased(Some(7))) =
    automation.task_transition_trigger(
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Available,
      Some(7),
    )

  let assert Ok(automation.TaskCompleted(Some(7))) =
    automation.task_transition_trigger(
      Some(task_status.Claimed(task_status.Taken)),
      task_status.Done,
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
  let done = automation.TaskCompleted(None)

  let assert "task_created:42" =
    automation.trigger_to_event_key(created, task_id)
  let assert "task_claimed:42" =
    automation.trigger_to_event_key(claimed, task_id)
  let assert "task_released:42" =
    automation.trigger_to_event_key(released, task_id)
  let assert "task_completed:42" =
    automation.trigger_to_event_key(done, task_id)
}

pub fn available_variables_exclude_legacy_and_due_date_values_test() {
  let trigger = automation.TaskCompleted(None)

  let assert False =
    automation.template_uses_unknown_variables(
      "{{origin}} {{trigger}} {{project}} {{user}} {{task_title}} {{task_type}}",
      trigger,
    )

  let assert True =
    automation.template_uses_unknown_variables("{{father}}", trigger)
  let assert True =
    automation.template_uses_unknown_variables("{{due_date}}", trigger)
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
      trigger: Some(automation.TaskCompleted(None)),
      template_id: None,
    )

  let assert Error(automation.MissingTemplate) =
    automation.validate_rule_draft(no_template)
}

pub fn rule_draft_rejects_invalid_template_id_test() {
  let draft =
    automation.RuleDraft(
      engine_id: Some(1),
      trigger: Some(automation.TaskCompleted(None)),
      template_id: Some(0),
    )

  let assert Error(automation.InvalidTemplateId(0)) =
    automation.validate_rule_draft(draft)
}

pub fn valid_rule_draft_creates_single_task_rule_test() {
  let draft =
    automation.RuleDraft(
      engine_id: Some(10),
      trigger: Some(automation.TaskCompleted(Some(7))),
      template_id: Some(20),
    )

  let assert Ok(valid) = automation.validate_rule_draft(draft)
  let assert 10 = automation.valid_rule_draft_engine_id(valid)
  let assert automation.TaskCompleted(Some(7)) =
    automation.valid_rule_draft_trigger(valid)
  let assert automation.CreateTask(20) =
    automation.valid_rule_draft_action(valid)

  let rule = automation.create_rule(30, valid, automation.Active)

  let assert 30 = automation.rule_id(rule)
  let assert 10 = automation.rule_engine_id(rule)
  let assert automation.TaskCompleted(Some(7)) = automation.rule_trigger(rule)
  let assert automation.CreateTask(20) = automation.rule_action(rule)
  let assert automation.Active = automation.rule_status(rule)
}
