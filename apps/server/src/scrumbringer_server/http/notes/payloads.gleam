//// Shared JSON payload decoders for note endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

pub type NotePayload {
  NotePayload(content: String)
}

pub type DecodeError {
  InvalidJson
}

pub fn decode_note(data: Dynamic) -> Result(NotePayload, DecodeError) {
  let decoder = {
    use content <- decode.field("content", decode.string)
    decode.success(content)
  }

  decode.run(data, decoder)
  |> result.map(NotePayload)
  |> result.map_error(fn(_) { InvalidJson })
}
