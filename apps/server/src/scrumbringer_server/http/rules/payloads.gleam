//// JSON payload decoders for workflow rule endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result

pub type CreatePayload {
  CreatePayload(
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Option(Int),
    to_state: String,
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
    active: Option(Int),
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
    use active <- decode.optional_field("active", False, decode.bool)
    decode.success(CreatePayload(
      name: name,
      goal: goal,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
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
    use active <- decode.optional_field(
      "active",
      None,
      decode.optional(decode.int),
    )
    decode.success(UpdatePayload(
      name: name,
      goal: goal,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
      active: active,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_execution_order(data: Dynamic) -> Result(Int, Nil) {
  let decoder = {
    use execution_order <- decode.optional_field(
      "execution_order",
      0,
      decode.int,
    )
    decode.success(execution_order)
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}
