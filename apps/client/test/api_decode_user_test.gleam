import gleam/dynamic/decode
import gleam/json
import gleeunit/should
import scrumbringer_client/api

pub fn user_payload_decoder_decodes_enveloped_user_test() {
  let body =
    "{\"data\":{\"user\":{\"id\":1,\"email\":\"admin@acme.com\",\"org_id\":1,\"org_role\":\"admin\",\"created_at\":\"2026-01-13T18:54:08Z\"}}}"

  let decoder = decode.field("data", api.user_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result
  |> should.be_ok
}
