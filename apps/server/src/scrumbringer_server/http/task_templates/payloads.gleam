//// JSON payload decoders for task template endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import scrumbringer_server/http/payload_decode

pub type CreatePayload {
  CreatePayload(name: String, description: String, type_id: Int, priority: Int)
}

pub type UpdatePayload {
  UpdatePayload(
    name: Option(String),
    description: Option(String),
    type_id: Option(Int),
    priority: Option(Int),
  )
}

pub fn decode_create(data: Dynamic) -> Result(CreatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use type_id <- decode.field("type_id", decode.int)
    use priority <- decode.optional_field("priority", 3, decode.int)
    decode.success(CreatePayload(
      name: name,
      description: description,
      type_id: type_id,
      priority: priority,
    ))
  }

  payload_decode.run(data, decoder)
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
    use type_id <- decode.optional_field(
      "type_id",
      None,
      decode.optional(decode.int),
    )
    use priority <- decode.optional_field(
      "priority",
      None,
      decode.optional(decode.int),
    )
    decode.success(UpdatePayload(
      name: name,
      description: description,
      type_id: type_id,
      priority: priority,
    ))
  }

  payload_decode.run(data, decoder)
}
