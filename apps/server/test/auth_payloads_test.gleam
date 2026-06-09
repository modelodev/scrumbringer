import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

import scrumbringer_server/http/auth/payloads

pub fn decode_registration_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"email\":\"admin@example.com\",\"password\":\"passwordpassword\",\"org_name\":\"Acme\",\"invite_token\":\"il_1\"}",
      decode.dynamic,
    )

  let assert Ok(payloads.RegistrationPayload(
    email: Some("admin@example.com"),
    password: "passwordpassword",
    org_name: Some("Acme"),
    invite_token: Some("il_1"),
  )) = payloads.decode_registration(dynamic)
}

pub fn decode_registration_payload_maps_empty_optional_fields_test() {
  let assert Ok(dynamic) =
    json.parse("{\"password\":\"passwordpassword\"}", decode.dynamic)

  let assert Ok(payloads.RegistrationPayload(
    email: None,
    org_name: None,
    invite_token: None,
    ..,
  )) = payloads.decode_registration(dynamic)
}

pub fn decode_registration_payload_rejects_short_password_test() {
  let assert Ok(dynamic) =
    json.parse("{\"password\":\"short\"}", decode.dynamic)

  let assert Error(payloads.PasswordTooShort) =
    payloads.decode_registration(dynamic)
}

pub fn decode_registration_payload_rejects_missing_password_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_registration(dynamic)
}

pub fn decode_login_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"email\":\"admin@example.com\",\"password\":\"passwordpassword\"}",
      decode.dynamic,
    )

  let assert Ok(payloads.LoginPayload(
    email: "admin@example.com",
    password: "passwordpassword",
  )) = payloads.decode_login(dynamic)
}

pub fn decode_login_payload_rejects_missing_password_test() {
  let assert Ok(dynamic) =
    json.parse("{\"email\":\"admin@example.com\"}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_login(dynamic)
}
