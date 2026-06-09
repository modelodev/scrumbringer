import gleam/dynamic/decode
import gleam/json

import scrumbringer_server/http/org_invite_links/payloads

pub fn decode_email_payload_normalizes_email_test() {
  let assert Ok(dynamic) =
    json.parse("{\"email\":\" Admin@Example.COM \"}", decode.dynamic)

  let assert Ok(payloads.EmailPayload(email: "admin@example.com")) =
    payloads.decode_email(dynamic)
}

pub fn decode_email_payload_rejects_missing_email_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_email(dynamic)
}

pub fn decode_email_payload_rejects_invalid_email_test() {
  let assert Ok(dynamic) =
    json.parse("{\"email\":\"admin@example\"}", decode.dynamic)

  let assert Error(payloads.InvalidEmail) = payloads.decode_email(dynamic)
}
