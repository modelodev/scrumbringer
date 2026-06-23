//// JSON payload decoders for workflow rule endpoints.

import domain/automation.{
  type AutomationAction, type AutomationRuleStatus, type AutomationTrigger,
  Active,
}
import domain/automation/automation_codec
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result

pub type CreatePayload {
  CreatePayload(
    name: String,
    goal: String,
    trigger: AutomationTrigger,
    action: AutomationAction,
    status: AutomationRuleStatus,
  )
}

pub type UpdatePayload {
  UpdatePayload(
    name: Option(String),
    goal: Option(String),
    trigger: Option(AutomationTrigger),
    action: Option(AutomationAction),
    status: Option(AutomationRuleStatus),
  )
}

pub fn decode_create(data: Dynamic) -> Result(CreatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use goal <- decode.optional_field("goal", "", decode.string)
    use trigger <- decode.field("trigger", automation_codec.trigger_decoder())
    use action <- decode.field("action", automation_codec.action_decoder())
    use status <- decode.optional_field(
      "status",
      Active,
      automation_codec.rule_status_decoder(),
    )
    decode.success(CreatePayload(
      name: name,
      goal: goal,
      trigger: trigger,
      action: action,
      status: status,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_update(data: Dynamic) -> Result(UpdatePayload, Nil) {
  let decoder = {
    use name <- decode.optional_field(
      "name",
      None,
      decode.optional(decode.string),
    )
    use goal <- decode.optional_field(
      "goal",
      None,
      decode.optional(decode.string),
    )
    use trigger <- decode.optional_field(
      "trigger",
      None,
      decode.optional(automation_codec.trigger_decoder()),
    )
    use action <- decode.optional_field(
      "action",
      None,
      decode.optional(automation_codec.action_decoder()),
    )
    use status <- decode.optional_field(
      "status",
      None,
      decode.optional(automation_codec.rule_status_decoder()),
    )
    decode.success(UpdatePayload(
      name: name,
      goal: goal,
      trigger: trigger,
      action: action,
      status: status,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}
