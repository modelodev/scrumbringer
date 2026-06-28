//// JSON payload decoders and validation for password reset endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import gleam/string
import scrumbringer_server/http/payload_decode

pub type ResetRequestPayload {
  ResetRequestPayload(email: String)
}

pub type ConsumePayload {
  ConsumePayload(token: String, password: String)
}

pub type DecodeError {
  InvalidJson
  EmailRequired
  PasswordTooShort
}

pub fn decode_reset_request(
  data: Dynamic,
) -> Result(ResetRequestPayload, DecodeError) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    decode.success(email)
  }

  use email <- result.try(payload_decode.run_error(data, decoder, InvalidJson))

  let email = string.trim(email)
  case email {
    "" -> Error(EmailRequired)
    email -> Ok(ResetRequestPayload(email: email))
  }
}

pub fn decode_consume(data: Dynamic) -> Result(ConsumePayload, DecodeError) {
  let decoder = {
    use token <- decode.field("token", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(#(token, password))
  }

  use payload <- result.try(payload_decode.run_error(data, decoder, InvalidJson))

  let #(token, password) = payload
  case string.length(password) < 12 {
    True -> Error(PasswordTooShort)
    False -> Ok(ConsumePayload(token: token, password: password))
  }
}
