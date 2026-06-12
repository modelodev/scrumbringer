//// Rule API functions for automation workflows.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{None, Some}

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/workflow.{type Rule, type RuleTarget, type RuleTemplate}
import domain/workflow/codec as workflow_codec
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

/// Decoder for list of rule templates.
pub fn rule_templates_payload_decoder() -> decode.Decoder(List(RuleTemplate)) {
  decode.field(
    "templates",
    decode.list(workflow_codec.rule_template_decoder()),
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
  target: RuleTarget,
  active: Bool,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #(
        "resource_type",
        json.string(workflow.rule_target_resource_type(target)),
      ),
      #("task_type_id", case workflow.rule_target_task_type_id(target) {
        None -> json.null()
        Some(id) -> json.int(id)
      }),
      #("to_state", json.string(workflow.rule_target_to_state_string(target))),
      #("active", json.bool(active)),
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
  target: RuleTarget,
  active: Bool,
  to_msg: fn(ApiResult(Rule)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("goal", json.string(goal)),
      #(
        "resource_type",
        json.string(workflow.rule_target_resource_type(target)),
      ),
      #("task_type_id", case workflow.rule_target_task_type_id(target) {
        None -> json.null()
        Some(id) -> json.int(id)
      }),
      #("to_state", json.string(workflow.rule_target_to_state_string(target))),
      #(
        "active",
        json.int(case active {
          True -> 1
          False -> 0
        }),
      ),
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

/// Attach template to rule.
pub fn attach_template(
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
  to_msg: fn(ApiResult(List(RuleTemplate))) -> msg,
) -> Effect(msg) {
  let body = json.object([#("execution_order", json.int(execution_order))])
  core.request(
    core.Post,
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/templates/"
      <> int.to_string(template_id),
    Some(body),
    rule_templates_payload_decoder(),
    to_msg,
  )
}

/// Detach template from rule.
pub fn detach_template(
  rule_id: Int,
  template_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/rules/"
      <> int.to_string(rule_id)
      <> "/templates/"
      <> int.to_string(template_id),
    None,
    to_msg,
  )
}
