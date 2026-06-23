//// JSON codecs for automation domain types.

import domain/automation
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option, None}
import helpers/json as json_helpers

// =============================================================================
// Trigger
// =============================================================================

pub fn trigger_decoder() -> decode.Decoder(automation.AutomationTrigger) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "task_created" -> task_trigger_decoder(automation.TaskCreated)
    "task_claimed" -> task_trigger_decoder(automation.TaskClaimed)
    "task_released" -> task_trigger_decoder(automation.TaskReleased)
    "task_completed" -> task_trigger_decoder(automation.TaskCompleted)
    "card_activated" -> card_trigger_decoder(automation.CardActivated)
    "card_closed" -> card_trigger_decoder(automation.CardClosed)
    _ -> decode.failure(automation.TaskCompleted(None), "AutomationTrigger")
  }
}

fn task_trigger_decoder(
  constructor: fn(Option(Int)) -> automation.AutomationTrigger,
) -> decode.Decoder(automation.AutomationTrigger) {
  use task_type_id <- decode.optional_field(
    "task_type_id",
    None,
    decode.optional(decode.int),
  )
  decode.success(constructor(task_type_id))
}

fn card_trigger_decoder(
  constructor: fn(automation.CardAutomationScope) ->
    automation.AutomationTrigger,
) -> decode.Decoder(automation.AutomationTrigger) {
  use scope <- decode.field("scope", scope_decoder())
  decode.success(constructor(scope))
}

pub fn trigger_to_json(trigger: automation.AutomationTrigger) -> Json {
  case trigger {
    automation.TaskCreated(task_type_id) ->
      task_trigger_to_json("task_created", task_type_id)
    automation.TaskClaimed(task_type_id) ->
      task_trigger_to_json("task_claimed", task_type_id)
    automation.TaskReleased(task_type_id) ->
      task_trigger_to_json("task_released", task_type_id)
    automation.TaskCompleted(task_type_id) ->
      task_trigger_to_json("task_completed", task_type_id)
    automation.CardActivated(scope) ->
      card_trigger_to_json("card_activated", scope)
    automation.CardClosed(scope) -> card_trigger_to_json("card_closed", scope)
  }
}

fn task_trigger_to_json(kind: String, task_type_id: Option(Int)) -> Json {
  json.object([
    #("type", json.string(kind)),
    #("task_type_id", json_helpers.option_int_json(task_type_id)),
  ])
}

fn card_trigger_to_json(
  kind: String,
  scope: automation.CardAutomationScope,
) -> Json {
  json.object([
    #("type", json.string(kind)),
    #("scope", scope_to_json(scope)),
  ])
}

// =============================================================================
// Card scope
// =============================================================================

pub fn scope_decoder() -> decode.Decoder(automation.CardAutomationScope) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "any_card" -> decode.success(automation.AnyCard)
    "at_depth" -> {
      use depth <- decode.field("depth", decode.int)
      case automation.card_depth_from_int(depth) {
        Ok(card_depth) -> decode.success(automation.AtDepth(card_depth))
        Error(_) -> decode.failure(automation.AnyCard, "CardDepth")
      }
    }
    _ -> decode.failure(automation.AnyCard, "CardAutomationScope")
  }
}

pub fn scope_to_json(scope: automation.CardAutomationScope) -> Json {
  case scope {
    automation.AnyCard ->
      json.object([
        #("type", json.string("any_card")),
      ])
    automation.AtDepth(depth) ->
      json.object([
        #("type", json.string("at_depth")),
        #("depth", json.int(automation.card_depth_to_int(depth))),
      ])
  }
}

// =============================================================================
// Action
// =============================================================================

pub fn action_decoder() -> decode.Decoder(automation.AutomationAction) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "create_task" -> {
      use template_id <- decode.field("template_id", decode.int)
      decode.success(automation.CreateTask(template_id))
    }
    _ -> decode.failure(automation.CreateTask(0), "AutomationAction")
  }
}

pub fn action_to_json(action: automation.AutomationAction) -> Json {
  case action {
    automation.CreateTask(template_id) ->
      json.object([
        #("type", json.string("create_task")),
        #("template_id", json.int(template_id)),
      ])
  }
}

// =============================================================================
// Rule status
// =============================================================================

pub fn rule_status_decoder() -> decode.Decoder(automation.AutomationRuleStatus) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "active" -> decode.success(automation.Active)
    "paused" -> decode.success(automation.Paused)
    "requires_review" -> {
      use reason <- decode.field("reason", review_reason_decoder())
      decode.success(automation.RequiresReview(reason))
    }
    _ -> decode.failure(automation.Paused, "AutomationRuleStatus")
  }
}

pub fn rule_status_to_json(status: automation.AutomationRuleStatus) -> Json {
  case status {
    automation.Active ->
      json.object([
        #("type", json.string("active")),
      ])
    automation.Paused ->
      json.object([
        #("type", json.string("paused")),
      ])
    automation.RequiresReview(reason) ->
      json.object([
        #("type", json.string("requires_review")),
        #("reason", review_reason_to_json(reason)),
      ])
  }
}

fn review_reason_decoder() -> decode.Decoder(automation.RuleReviewReason) {
  use value <- decode.then(decode.string)
  case value {
    "template_missing" -> decode.success(automation.TemplateMissing)
    "task_type_missing" -> decode.success(automation.TaskTypeMissing)
    "card_depth_no_longer_exists" ->
      decode.success(automation.CardDepthNoLongerExists)
    "invalid_migrated_data" -> decode.success(automation.InvalidMigratedData)
    _ -> decode.failure(automation.InvalidMigratedData, "RuleReviewReason")
  }
}

fn review_reason_to_json(reason: automation.RuleReviewReason) -> Json {
  case reason {
    automation.TemplateMissing -> json.string("template_missing")
    automation.TaskTypeMissing -> json.string("task_type_missing")
    automation.CardDepthNoLongerExists ->
      json.string("card_depth_no_longer_exists")
    automation.InvalidMigratedData -> json.string("invalid_migrated_data")
  }
}

// =============================================================================
// Rule draft
// =============================================================================

pub fn rule_draft_decoder() -> decode.Decoder(automation.RuleDraft) {
  use engine_id <- decode.optional_field(
    "engine_id",
    None,
    decode.optional(decode.int),
  )
  use trigger <- decode.optional_field(
    "trigger",
    None,
    decode.optional(trigger_decoder()),
  )
  use template_id <- decode.optional_field(
    "template_id",
    None,
    decode.optional(decode.int),
  )

  decode.success(automation.RuleDraft(
    engine_id: engine_id,
    trigger: trigger,
    template_id: template_id,
  ))
}

pub fn rule_draft_to_json(draft: automation.RuleDraft) -> Json {
  json.object([
    #("engine_id", json_helpers.option_int_json(draft.engine_id)),
    #("trigger", json_helpers.option_to_json(draft.trigger, trigger_to_json)),
    #("template_id", json_helpers.option_int_json(draft.template_id)),
  ])
}
