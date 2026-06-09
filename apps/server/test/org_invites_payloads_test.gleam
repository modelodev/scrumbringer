import gleam/dynamic/decode
import gleam/json

import scrumbringer_server/http/org_invites/payloads

pub fn decode_create_invite_payload_uses_default_expiry_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Ok(payloads.CreateInvitePayload(expires_in_hours: 168)) =
    payloads.decode_create(dynamic)
}

pub fn decode_create_invite_payload_accepts_expiry_test() {
  let assert Ok(dynamic) =
    json.parse("{\"expires_in_hours\":24}", decode.dynamic)

  let assert Ok(payloads.CreateInvitePayload(expires_in_hours: 24)) =
    payloads.decode_create(dynamic)
}

pub fn decode_create_invite_payload_rejects_invalid_expiry_type_test() {
  let assert Ok(dynamic) =
    json.parse("{\"expires_in_hours\":\"soon\"}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_create(dynamic)
}
