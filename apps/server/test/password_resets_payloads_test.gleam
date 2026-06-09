import gleam/dynamic/decode
import gleam/json

import scrumbringer_server/http/password_resets/payloads

pub fn decode_reset_request_payload_trims_email_test() {
  let assert Ok(dynamic) =
    json.parse("{\"email\":\" admin@example.com \"}", decode.dynamic)

  let assert Ok(payloads.ResetRequestPayload(email: "admin@example.com")) =
    payloads.decode_reset_request(dynamic)
}

pub fn decode_reset_request_payload_rejects_missing_email_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(payloads.InvalidJson) =
    payloads.decode_reset_request(dynamic)
}

pub fn decode_reset_request_payload_rejects_blank_email_test() {
  let assert Ok(dynamic) = json.parse("{\"email\":\"   \"}", decode.dynamic)

  let assert Error(payloads.EmailRequired) =
    payloads.decode_reset_request(dynamic)
}

pub fn decode_consume_payload_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"token\":\"pr_token\",\"password\":\"passwordpassword\"}",
      decode.dynamic,
    )

  let assert Ok(payloads.ConsumePayload(
    token: "pr_token",
    password: "passwordpassword",
  )) = payloads.decode_consume(dynamic)
}

pub fn decode_consume_payload_rejects_missing_password_test() {
  let assert Ok(dynamic) =
    json.parse("{\"token\":\"pr_token\"}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_consume(dynamic)
}

pub fn decode_consume_payload_rejects_short_password_test() {
  let assert Ok(dynamic) =
    json.parse(
      "{\"token\":\"pr_token\",\"password\":\"short\"}",
      decode.dynamic,
    )

  let assert Error(payloads.PasswordTooShort) = payloads.decode_consume(dynamic)
}
