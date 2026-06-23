//// JSON payload decoders for workflow rule endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result
import scrumbringer_server/http/payload_fields

pub type CreatePayload {
  CreatePayload(
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Option(Int),
    to_state: String,
    template_id: Option(Int),
    active: Bool,
  )
}

pub type UpdatePayload {
  UpdatePayload(
    name: Option(String),
    goal: Option(String),
    resource_type: Option(String),
    task_type_id: Option(Int),
    to_state: Option(String),
    template_id: Option(Int),
    active: Option(Bool),
  )
}

pub fn decode_create(data: Dynamic) -> Result(CreatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use goal <- decode.optional_field("goal", "", decode.string)
    use resource_type <- decode.field("resource_type", decode.string)
    use task_type_id <- decode.optional_field(
      "task_type_id",
      None,
      decode.optional(decode.int),
    )
    use to_state <- decode.field("to_state", decode.string)
    use template_id <- decode.optional_field(
      "template_id",
      None,
      decode.optional(decode.int),
    )
    use active <- decode.optional_field("active", False, decode.bool)
    decode.success(CreatePayload(
      name: name,
      goal: goal,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
      template_id: template_id,
      active: active,
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
    use resource_type <- decode.optional_field(
      "resource_type",
      None,
      decode.optional(decode.string),
    )
    use task_type_id <- decode.optional_field(
      "task_type_id",
      None,
      decode.optional(decode.int),
    )
    use to_state <- decode.optional_field(
      "to_state",
      None,
      decode.optional(decode.string),
    )
    use template_id <- decode.optional_field(
      "template_id",
      None,
      decode.optional(decode.int),
    )
    use active <- decode.optional_field(
      "active",
      None,
      payload_fields.optional_active_flag_decoder(),
    )
    decode.success(UpdatePayload(
      name: name,
      goal: goal,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
      template_id: template_id,
      active: active,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}
