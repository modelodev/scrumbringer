//// Rule API functions for automation workflows.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{None, Some}

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/automation.{
  type AutomationAction, type AutomationRuleStatus, type AutomationTrigger,
}
import domain/automation/automation_codec
import domain/workflow.{type Rule}
import domain/workflow/workflow_codec
import scrumbringer_client/api/core

/// Decoder for rule wrapped in envelope.
pub fn rule_payload_decoder() -> decode.Decoder(Rule) {
  decode.field("rule", workflow_codec.rule_decoder(), decode.success)
}

/// Decoder for list of rules.
pub fn rules_payload_decoder() -> decode.Decoder(List(Rule)) {
  decode.field(
    "rules",
    decode.list(workflow_codec.rule_decoder()),
    decode.success,
  )
}

/// List rules for a workflow.
pub fn list_rules(
  workflow_id: Int,
  to_msg: fn(ApiResult(List(Rule))) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
    None,
    rules_payload_decoder(),
    to_msg,
  )
}

/// Create rule in a workflow.
pub fn create_rule(
  workflow_id: Int,
  name: String,
  goal: String,
  trigger: AutomationTrigger,
  action: AutomationAction,
  status: AutomationRuleStatus,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #("trigger", automation_codec.trigger_to_json(trigger)),
      #("action", automation_codec.action_to_json(action)),
      #("status", automation_codec.rule_status_to_json(status)),
    ])
  core.request(
    core.Post,
    "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
    Some(body),
    rule_payload_decoder(),
    to_msg,
  )
}

/// Update rule.
pub fn update_rule(
  rule_id: Int,
  name: String,
  goal: String,
  trigger: AutomationTrigger,
  action: AutomationAction,
  status: AutomationRuleStatus,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #("trigger", automation_codec.trigger_to_json(trigger)),
      #("action", automation_codec.action_to_json(action)),
      #("status", automation_codec.rule_status_to_json(status)),
    ])
  core.request(
    core.Patch,
    "/api/v1/rules/" <> int.to_string(rule_id),
    Some(body),
    rule_payload_decoder(),
    to_msg,
  )
}

/// Delete rule.
pub fn delete_rule(
  rule_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/rules/" <> int.to_string(rule_id),
    None,
    to_msg,
  )
}
