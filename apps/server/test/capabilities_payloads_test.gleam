import gleam/dynamic/decode
import gleam/json

import scrumbringer_server/http/capabilities/payloads

pub fn decode_create_payload_test() {
  let assert Ok(dynamic) = json.parse("{\"name\":\"Backend\"}", decode.dynamic)

  let assert Ok(payloads.CreatePayload(name: "Backend")) =
    payloads.decode_create(dynamic)
}

pub fn decode_create_payload_rejects_missing_name_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_create(dynamic)
}

pub fn decode_capability_ids_payload_test() {
  let assert Ok(dynamic) =
    json.parse("{\"capability_ids\":[1,2,3]}", decode.dynamic)

  let assert Ok(payloads.CapabilityIdsPayload(capability_ids: [1, 2, 3])) =
    payloads.decode_capability_ids(dynamic)
}

pub fn decode_capability_ids_payload_rejects_non_int_ids_test() {
  let assert Ok(dynamic) =
    json.parse("{\"capability_ids\":[\"1\"]}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_capability_ids(dynamic)
}

pub fn decode_user_ids_payload_test() {
  let assert Ok(dynamic) = json.parse("{\"user_ids\":[4,5]}", decode.dynamic)

  let assert Ok(payloads.UserIdsPayload(user_ids: [4, 5])) =
    payloads.decode_user_ids(dynamic)
}

pub fn decode_user_ids_payload_rejects_missing_user_ids_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(Nil) = payloads.decode_user_ids(dynamic)
}
