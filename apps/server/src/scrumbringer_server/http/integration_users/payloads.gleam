import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

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

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}
