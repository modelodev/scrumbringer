//// JSON payload decoders and validation for auth endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type RegistrationPayload {
  RegistrationPayload(
    email: Option(String),
    password: String,
    org_name: Option(String),
    invite_token: Option(String),
  )
}

pub type LoginPayload {
  LoginPayload(email: String, password: String)
}

pub type DecodeError {
  InvalidJson
  PasswordTooShort
}

pub fn decode_registration(
  data: Dynamic,
) -> Result(RegistrationPayload, DecodeError) {
  let decoder = {
    use email <- decode.optional_field("email", "", decode.string)
    use password <- decode.field("password", decode.string)
    use org_name <- decode.optional_field("org_name", "", decode.string)
    use invite_token <- decode.optional_field("invite_token", "", decode.string)
    decode.success(#(email, password, org_name, invite_token))
  }

  use payload <- result.try(
    decode.run(data, decoder)
    |> result.map_error(fn(_) { InvalidJson }),
  )

  let #(email, password, org_name, invite_token) = payload
  case string.length(password) < 12 {
    True -> Error(PasswordTooShort)
    False ->
      Ok(RegistrationPayload(
        email: empty_to_option(email),
        password: password,
        org_name: empty_to_option(org_name),
        invite_token: empty_to_option(invite_token),
      ))
  }
}

pub fn decode_login(data: Dynamic) -> Result(LoginPayload, DecodeError) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(LoginPayload(email: email, password: password))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}

fn empty_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    _ -> Some(value)
  }
}
