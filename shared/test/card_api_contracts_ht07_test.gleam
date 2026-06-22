import api/cards/contracts
import gleam/dynamic/decode
import gleam/json
import gleam/option

import domain/card

pub fn list_cards_by_depth_scope_test() {
  let assert Ok(contracts.DepthScope(2)) =
    json.parse("{\"depth\":2}", contracts.depth_scope_codec())
}

pub fn move_card_api_contract_roundtrip_test() {
  let assert Ok(payload) = json.parse("{\"parent_card_id\":12}", decode.dynamic)

  let assert Ok(request) = contracts.decode_card_move(payload)
  let assert contracts.CardMoveRequest(parent_card_id: option.Some(12)) =
    request
}

pub fn move_card_api_contract_accepts_root_parent_test() {
  let assert Ok(payload) =
    json.parse("{\"parent_card_id\":null}", decode.dynamic)

  let assert Ok(request) = contracts.decode_card_move(payload)
  let assert contracts.CardMoveRequest(parent_card_id: option.None) = request
}

pub fn activate_card_api_contract_roundtrip_test() {
  let body =
    contracts.CardActionResponse(
      card_id: 7,
      pool_impact: 3,
      pool_open_after: 12,
      healthy_pool_limit: 10,
      pool_health: contracts.PoolExceedsHealthyLimit,
    )
    |> contracts.action_response_to_json
    |> json.to_string

  let assert Ok(card_id) = json.parse(body, int_field("card_id"))
  let assert Ok(pool_impact) = json.parse(body, int_field("pool_impact"))
  let assert Ok(pool_open_after) =
    json.parse(body, int_field("pool_open_after"))
  let assert Ok(healthy_pool_limit) =
    json.parse(body, int_field("healthy_pool_limit"))
  let assert 7 = card_id
  let assert 3 = pool_impact
  let assert 12 = pool_open_after
  let assert 10 = healthy_pool_limit
}

pub fn close_card_api_contract_roundtrip_test() {
  let assert Ok(payload) =
    json.parse("{\"reason\":\"manually_closed\"}", decode.dynamic)

  let assert Ok(contracts.CardCloseRequest(reason: "manually_closed")) =
    contracts.decode_card_close(payload)
}

pub fn card_endpoints_reject_invalid_requests_test() {
  let assert Ok(payload) =
    json.parse(
      "{\"title\":\"Feature\",\"color\":\"not-a-color\"}",
      decode.dynamic,
    )

  let assert Error(contracts.InvalidColor) =
    contracts.decode_card_create(payload)
}

pub fn card_create_request_codec_accepts_parent_card_test() {
  let assert Ok(payload) =
    json.parse(
      "{\"title\":\"Feature\",\"description\":\"Desc\",\"color\":\"blue\",\"parent_card_id\":5}",
      decode.dynamic,
    )

  let assert Ok(request) = contracts.decode_card_create(payload)
  let assert contracts.CardCreateRequest(
    title: "Feature",
    description: option.Some("Desc"),
    color: option.Some(card.Blue),
    parent_card_id: option.Some(5),
    due_date: option.None,
  ) = request
}

fn int_field(name: String) -> decode.Decoder(Int) {
  use value <- decode.field(name, decode.int)
  decode.success(value)
}
