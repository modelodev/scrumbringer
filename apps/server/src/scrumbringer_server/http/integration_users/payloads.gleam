import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import scrumbringer_server/http/payload_decode

pub type CreateIntegrationUserPayload {
  CreateIntegrationUserPayload(email: String)
}

pub type DecodeError {
  InvalidJson
}

pub fn decode_create(
  data: Dynamic,
) -> Result(CreateIntegrationUserPayload, DecodeError) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    decode.success(CreateIntegrationUserPayload(email: email))
  }

  payload_decode.run_error(data, decoder, InvalidJson)
}
