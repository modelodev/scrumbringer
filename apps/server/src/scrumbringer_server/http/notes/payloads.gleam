//// Shared JSON payload decoders for note endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import scrumbringer_server/http/payload_decode

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

  payload_decode.run_error(data, decoder, InvalidJson)
}
