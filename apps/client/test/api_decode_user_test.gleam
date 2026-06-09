import gleam/dynamic/decode
import gleam/json
import scrumbringer_client/api/auth as api_auth

pub fn user_payload_decoder_decodes_enveloped_user_test() {
  let body =
    "{\"data\":{\"user\":{\"id\":1,\"email\":\"admin@acme.com\",\"org_id\":1,\"org_role\":\"admin\",\"created_at\":\"2026-01-13T18:54:08Z\"}}}"

  let decoder =
    decode.field("data", api_auth.user_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  let assert Ok(_) = result
}

pub fn user_payload_decoder_rejects_missing_email_test() {
  let body =
    "{\"data\":{\"user\":{\"id\":1,\"org_id\":1,\"org_role\":\"admin\",\"created_at\":\"2026-01-13T18:54:08Z\"}}}"

  let decoder =
    decode.field("data", api_auth.user_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  let assert Error(_) = result
}
