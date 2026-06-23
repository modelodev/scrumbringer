import gleam/json
import gleam/option

import domain/automation
import domain/workflow.{Rule}
import domain/workflow/workflow_codec as codec

pub fn rule_decoder_decodes_typed_task_target_test() {
  let body =
    "{\"id\":1,\"workflow_id\":2,\"name\":\"Complete task\",\"goal\":null,\"trigger\":{\"type\":\"task_completed\",\"task_type_id\":7},\"action\":{\"type\":\"create_task\",\"template_id\":11},\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-28T12:00:00Z\",\"template\":null}"

  let assert Ok(Rule(
    id: 1,
    workflow_id: 2,
    name: "Complete task",
    goal: option.None,
    trigger: automation.TaskCompleted(option.Some(7)),
    action: option.Some(automation.CreateTask(11)),
    status: automation.Active,
    created_at: "2026-01-28T12:00:00Z",
    template: option.None,
  )) = json.parse(body, codec.rule_decoder())
}

pub fn rule_decoder_rejects_missing_trigger_test() {
  let body =
    "{\"id\":1,\"workflow_id\":2,\"name\":\"Complete task\",\"goal\":null,\"action\":{\"type\":\"create_task\",\"template_id\":11},\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-28T12:00:00Z\",\"template\":null}"

  let assert Error(_) = json.parse(body, codec.rule_decoder())
}

pub fn rule_decoder_rejects_active_rule_without_action_test() {
  let body =
    "{\"id\":1,\"workflow_id\":2,\"name\":\"Missing template\",\"goal\":null,\"trigger\":{\"type\":\"task_completed\",\"task_type_id\":7},\"action\":null,\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-28T12:00:00Z\",\"template\":null}"

  let assert Error(_) = json.parse(body, codec.rule_decoder())
}

pub fn rule_decoder_accepts_requires_review_without_action_test() {
  let body =
    "{\"id\":1,\"workflow_id\":2,\"name\":\"Missing template\",\"goal\":null,\"trigger\":{\"type\":\"task_completed\",\"task_type_id\":7},\"action\":null,\"status\":{\"type\":\"requires_review\",\"reason\":\"template_missing\"},\"created_at\":\"2026-01-28T12:00:00Z\",\"template\":null}"

  let assert Ok(Rule(
    action: option.None,
    status: automation.RequiresReview(automation.TemplateMissing),
    ..,
  )) = json.parse(body, codec.rule_decoder())
}
