//// JSON payload decoders for organization invite endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import scrumbringer_server/http/payload_decode

const default_expires_in_hours = 168

pub type CreateInvitePayload {
  CreateInvitePayload(expires_in_hours: Int)
}

pub type DecodeError {
  InvalidJson
}

pub fn decode_create(data: Dynamic) -> Result(CreateInvitePayload, DecodeError) {
  let decoder = {
    use hours <- decode.optional_field(
      "expires_in_hours",
      default_expires_in_hours,
      decode.int,
    )
    decode.success(hours)
  }

  payload_decode.run_error(data, decoder, InvalidJson)
  |> result.map(CreateInvitePayload)
}
