//// JSON payload decoders for milestone endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result

pub type CreatePayload {
  CreatePayload(name: String, description: Option(String))
}

pub type PatchPayload {
  PatchPayload(name: Option(String), description: Option(String))
}

pub fn decode_create(data: Dynamic) -> Result(CreatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.optional_field(
      "description",
      None,
      decode.optional(decode.string),
    )
    decode.success(CreatePayload(name:, description:))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_patch(data: Dynamic) -> Result(PatchPayload, Nil) {
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
    decode.success(PatchPayload(name:, description:))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { Nil })
}
