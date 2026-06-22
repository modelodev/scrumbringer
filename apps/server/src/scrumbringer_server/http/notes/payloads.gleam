//// Shared JSON payload decoders for note endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result

pub type NotePayload {
  NotePayload(content: String, url: Option(String))
}

pub type DecodeError {
  InvalidJson
}

pub fn decode_note(data: Dynamic) -> Result(NotePayload, DecodeError) {
  let decoder = {
    use content <- decode.field("content", decode.string)
    use url <- decode.optional_field(
      "url",
      None,
      decode.optional(decode.string),
    )
    decode.success(NotePayload(content: content, url: url))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}
