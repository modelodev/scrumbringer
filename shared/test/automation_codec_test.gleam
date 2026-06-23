import domain/automation
import domain/automation/automation_codec
import gleam/json
import gleam/option.{None, Some}

pub fn task_trigger_codecs_roundtrip_supported_triggers_test() {
  let created = automation.TaskCreated(None)
  let claimed = automation.TaskClaimed(Some(7))
  let released = automation.TaskReleased(None)
  let completed = automation.TaskCompleted(Some(9))

  let assert Ok(decoded_created) = roundtrip_trigger(created)
  let assert True = decoded_created == created
  let assert Ok(decoded_claimed) = roundtrip_trigger(claimed)
  let assert True = decoded_claimed == claimed
  let assert Ok(decoded_released) = roundtrip_trigger(released)
  let assert True = decoded_released == released
  let assert Ok(decoded_completed) = roundtrip_trigger(completed)
  let assert True = decoded_completed == completed
}

pub fn card_trigger_codecs_roundtrip_allowed_scopes_test() {
  let assert Ok(depth) = automation.card_depth_from_int(3)

  let activated = automation.CardActivated(automation.AnyCard)
  let closed = automation.CardClosed(automation.AtDepth(depth))

  let assert Ok(decoded_activated) = roundtrip_trigger(activated)
  let assert True = decoded_activated == activated
  let assert Ok(automation.CardClosed(automation.AtDepth(decoded_depth))) =
    roundtrip_trigger(closed)
  let assert 3 = automation.card_depth_to_int(decoded_depth)
}

pub fn trigger_decoder_rejects_parked_and_due_date_triggers_test() {
  let blocked = "{\"type\":\"task_blocked\",\"task_type_id\":null}"
  let due_date = "{\"type\":\"task_due_date_overdue\"}"

  let assert Error(_) = json.parse(blocked, automation_codec.trigger_decoder())
  let assert Error(_) = json.parse(due_date, automation_codec.trigger_decoder())
}

pub fn trigger_decoder_rejects_invalid_card_depth_test() {
  let body =
    "{\"type\":\"card_activated\",\"scope\":{\"type\":\"at_depth\",\"depth\":0}}"

  let assert Error(_) = json.parse(body, automation_codec.trigger_decoder())
}

pub fn action_codec_roundtrips_single_create_task_action_test() {
  let action = automation.CreateTask(42)

  let assert Ok(decoded) =
    action
    |> automation_codec.action_to_json
    |> json.to_string
    |> json.parse(automation_codec.action_decoder())
  let assert True = decoded == action
}

pub fn rule_status_codec_roundtrips_requires_review_reason_test() {
  let status = automation.RequiresReview(automation.TemplateMissing)

  let assert Ok(decoded) =
    status
    |> automation_codec.rule_status_to_json
    |> json.to_string
    |> json.parse(automation_codec.rule_status_decoder())
  let assert True = decoded == status
}

pub fn rule_draft_codec_roundtrips_builder_state_test() {
  let draft =
    automation.RuleDraft(
      engine_id: Some(10),
      trigger: Some(automation.TaskCompleted(Some(7))),
      template_id: Some(20),
    )

  let assert Ok(decoded) =
    draft
    |> automation_codec.rule_draft_to_json
    |> json.to_string
    |> json.parse(automation_codec.rule_draft_decoder())
  let assert Ok(valid) = automation.validate_rule_draft(decoded)
  let assert 10 = automation.valid_rule_draft_engine_id(valid)
  let assert automation.TaskCompleted(Some(7)) =
    automation.valid_rule_draft_trigger(valid)
  let assert automation.CreateTask(20) =
    automation.valid_rule_draft_action(valid)
}

pub fn rule_draft_decoder_accepts_missing_incomplete_builder_fields_test() {
  let body = "{}"

  let assert Ok(decoded) =
    json.parse(body, automation_codec.rule_draft_decoder())
  let assert Error(automation.MissingEngine) =
    automation.validate_rule_draft(decoded)
}

fn roundtrip_trigger(
  trigger: automation.AutomationTrigger,
) -> Result(automation.AutomationTrigger, json.DecodeError) {
  trigger
  |> automation_codec.trigger_to_json
  |> json.to_string
  |> json.parse(automation_codec.trigger_decoder())
}
