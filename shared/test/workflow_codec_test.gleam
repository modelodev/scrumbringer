import gleam/json
import gleam/option

import domain/task_status
import domain/workflow.{Rule, TaskRule}
import domain/workflow/workflow_codec as codec

pub fn rule_decoder_decodes_typed_task_target_test() {
  let body =
    "{\"id\":1,\"workflow_id\":2,\"name\":\"Complete task\",\"goal\":null,\"resource_type\":\"task\",\"task_type_id\":7,\"to_state\":\"completed\",\"active\":true,\"created_at\":\"2026-01-28T12:00:00Z\",\"template\":null}"

  let assert Ok(Rule(
    id: 1,
    workflow_id: 2,
    name: "Complete task",
    goal: option.None,
    target: TaskRule(task_status.Done, option.Some(7)),
    active: True,
    created_at: "2026-01-28T12:00:00Z",
    template: option.None,
  )) = json.parse(body, codec.rule_decoder())
}

pub fn rule_decoder_rejects_invalid_task_target_state_test() {
  let body =
    "{\"id\":1,\"workflow_id\":2,\"name\":\"Complete task\",\"goal\":null,\"resource_type\":\"task\",\"task_type_id\":7,\"to_state\":\"done\",\"active\":true,\"created_at\":\"2026-01-28T12:00:00Z\",\"template\":null}"

  let assert Error(_) = json.parse(body, codec.rule_decoder())
}
