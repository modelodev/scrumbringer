//// JSON payload decoders for workflow endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result

pub type CreatePayload {
  CreatePayload(name: String, description: String, active: Bool)
}

pub type UpdatePayload {
  UpdatePayload(
    name: Option(String),
    description: Option(String),
    active: Option(Bool),
  )
}

pub fn decode_create(data: Dynamic) -> Result(CreatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use active <- decode.optional_field("active", False, decode.bool)
    decode.success(CreatePayload(
      name: name,
      description: description,
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
    use description <- decode.optional_field(
      "description",
      None,
      decode.optional(decode.string),
    )
    use active <- decode.optional_field(
      "active",
      None,
      decode.optional(decode.bool),
    )
    decode.success(UpdatePayload(
      name: name,
      description: description,
      active: active,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}
