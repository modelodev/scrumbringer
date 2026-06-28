//// JSON payload decoders and validation for organization invite links.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import gleam/string
import scrumbringer_server/http/payload_decode

pub type EmailPayload {
  EmailPayload(email: String)
}

pub type DecodeError {
  InvalidJson
  InvalidEmail
}

pub fn decode_email(data: Dynamic) -> Result(EmailPayload, DecodeError) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    decode.success(email)
  }

  use email <- result.try(payload_decode.run_error(data, decoder, InvalidJson))

  let email = normalize_email(email)
  case validate_email(email) {
    Error(Nil) -> Error(InvalidEmail)
    Ok(Nil) -> Ok(EmailPayload(email: email))
  }
}

fn normalize_email(email: String) -> String {
  email
  |> string.trim
  |> string.lowercase
}

fn validate_email(email: String) -> Result(Nil, Nil) {
  case string.split_once(email, "@") {
    Error(_) -> Error(Nil)
    Ok(#(local, domain)) -> validate_email_parts(local, domain)
  }
}

fn validate_email_parts(local: String, domain: String) -> Result(Nil, Nil) {
  case local == "" || domain == "" {
    True -> Error(Nil)
    False -> validate_domain(domain)
  }
}

fn validate_domain(domain: String) -> Result(Nil, Nil) {
  case string.contains(domain, ".") {
    True -> Ok(Nil)
    False -> Error(Nil)
  }
}
