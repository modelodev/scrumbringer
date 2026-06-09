import domain/org
import gleam/dynamic/decode
import gleam/json
import scrumbringer_client/api/org as api_org

pub fn invite_links_payload_decoder_decodes_enveloped_list_test() {
  let body =
    "{\"data\":{\"invite_links\":[{\"email\":\"a@example.com\",\"token\":\"il_abc\",\"url_path\":\"/accept-invite?token=il_abc\",\"state\":\"active\",\"created_at\":\"2026-01-13T00:00:00Z\",\"used_at\":null,\"invalidated_at\":null}]}}"

  let decoder =
    decode.field("data", api_org.invite_links_payload_decoder(), decode.success)

  let assert Ok([link]) = json.parse(from: body, using: decoder)
  let assert org.Active = link.state
}

pub fn invite_link_payload_decoder_decodes_enveloped_resource_test() {
  let body =
    "{\"data\":{\"invite_link\":{\"email\":\"a@example.com\",\"token\":\"il_abc\",\"url_path\":\"/accept-invite?token=il_abc\",\"state\":\"active\",\"created_at\":\"2026-01-13T00:00:00Z\",\"used_at\":null,\"invalidated_at\":null}}}"

  let decoder =
    decode.field("data", api_org.invite_link_payload_decoder(), decode.success)

  let assert Ok(link) = json.parse(from: body, using: decoder)
  let assert org.Active = link.state
}

pub fn invite_link_payload_decoder_rejects_missing_token_test() {
  let body =
    "{\"data\":{\"invite_link\":{\"email\":\"a@example.com\",\"url_path\":\"/accept-invite?token=il_abc\",\"state\":\"active\",\"created_at\":\"2026-01-13T00:00:00Z\",\"used_at\":null,\"invalidated_at\":null}}}"

  let decoder =
    decode.field("data", api_org.invite_link_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  let assert Error(_) = result
}

pub fn invite_link_payload_decoder_rejects_unknown_state_test() {
  let body =
    "{\"data\":{\"invite_link\":{\"email\":\"a@example.com\",\"token\":\"il_abc\",\"url_path\":\"/accept-invite?token=il_abc\",\"state\":\"pending\",\"created_at\":\"2026-01-13T00:00:00Z\",\"used_at\":null,\"invalidated_at\":null}}}"

  let decoder =
    decode.field("data", api_org.invite_link_payload_decoder(), decode.success)

  let assert Error(_) = json.parse(from: body, using: decoder)
}
