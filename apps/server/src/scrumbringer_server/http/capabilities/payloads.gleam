//// JSON payload decoders for capability endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import scrumbringer_server/http/payload_decode

pub type CreatePayload {
  CreatePayload(name: String)
}

pub type CapabilityIdsPayload {
  CapabilityIdsPayload(capability_ids: List(Int))
}

pub type UserIdsPayload {
  UserIdsPayload(user_ids: List(Int))
}

pub fn decode_create(data: Dynamic) -> Result(CreatePayload, Nil) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(CreatePayload(name: name))
  }

  payload_decode.run(data, decoder)
}

pub fn decode_capability_ids(data: Dynamic) -> Result(CapabilityIdsPayload, Nil) {
  let decoder = {
    use ids <- decode.field("capability_ids", decode.list(decode.int))
    decode.success(CapabilityIdsPayload(capability_ids: ids))
  }

  payload_decode.run(data, decoder)
}

pub fn decode_user_ids(data: Dynamic) -> Result(UserIdsPayload, Nil) {
  let decoder = {
    use ids <- decode.field("user_ids", decode.list(decode.int))
    decode.success(UserIdsPayload(user_ids: ids))
  }

  payload_decode.run(data, decoder)
}
