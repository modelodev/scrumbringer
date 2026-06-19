import gleam/option.{None, Some}

import domain/card
import domain/task_status
import domain/workflow

pub fn parse_rule_target_returns_typed_task_target_test() {
  let assert Ok(workflow.TaskRule(task_status.Done, Some(1))) =
    workflow.parse_rule_target("task", Some(1), "completed")
}

pub fn parse_rule_target_returns_typed_card_target_test() {
  let assert Ok(workflow.CardRule(card.Closed)) =
    workflow.parse_rule_target("card", None, "cerrada")
}

pub fn rule_target_projection_values_match_boundary_strings_test() {
  let assert Ok(target) = workflow.parse_rule_target("task", Some(7), "claimed")

  let assert "task" = workflow.rule_target_resource_type(target)
  let assert Some(7) = workflow.rule_target_task_type_id(target)
  let assert "claimed" = workflow.rule_target_to_state_string(target)
  let assert #("task", 7, "claimed") = workflow.rule_target_to_db_values(target)
}

pub fn card_rule_target_db_values_do_not_emit_task_type_test() {
  let assert Ok(target) = workflow.parse_rule_target("card", None, "cerrada")

  let assert #("card", 0, "cerrada") = workflow.rule_target_to_db_values(target)
}

pub fn validate_task_rule_target_accepts_known_task_states_test() {
  let assert Ok(Nil) =
    workflow.validate_rule_target("task", Some(1), "completed")
  let assert Ok(Nil) = workflow.validate_rule_target("task", None, "claimed")
}

pub fn validate_task_rule_target_rejects_unknown_task_state_test() {
  let assert Error(workflow.InvalidTaskRuleState("done")) =
    workflow.validate_rule_target("task", None, "done")
}

pub fn validate_card_rule_target_accepts_known_card_states_test() {
  let assert Ok(Nil) = workflow.validate_rule_target("card", None, "cerrada")
}

pub fn validate_card_rule_target_rejects_task_type_test() {
  let assert Error(workflow.CardRuleCannotHaveTaskType) =
    workflow.validate_rule_target("card", Some(1), "cerrada")
}

pub fn validate_rule_target_rejects_unknown_resource_type_test() {
  let assert Error(workflow.UnknownRuleResourceType("event")) =
    workflow.validate_rule_target("event", None, "completed")
}
